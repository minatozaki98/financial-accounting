using API.Helpers;
using Asp.Versioning;
using Azure.Core;
using BAL.IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MODEL.ApplicationConfig;
using MODEL.DTOs;
using REPOSITORY.UnitOfWork;
using System.Numerics;
using System.Text;
using Microsoft.CognitiveServices.Speech;
using Microsoft.CognitiveServices.Speech.Audio;
using System.Text.Json;
using Microsoft.CognitiveServices.Speech.Transcription;
using Azure.Storage.Blobs;
using Microsoft.EntityFrameworkCore.Storage.Json;
using static System.Net.Mime.MediaTypeNames;
using System.IO;
using NAudio.Wave;

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
    // [Authorize]
    public class TextToSpeechV2Controller : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ITextToSpeechService _textToSpeechService;
        public TextToSpeechV2Controller(IUnitOfWork unitOfWork, ITextToSpeechService textToSpeechService)
        {
            _unitOfWork = unitOfWork;
            _textToSpeechService = textToSpeechService;
        }

        static readonly JsonSerializerOptions _options = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true,
        };

        [HttpPost("AddTextToSpeech")]
        public async Task<IActionResult> AddTextToSpeech(RequestMethodDTO inputModel)
        {
            try
            {
                string AliasMessage = inputModel.RequestMessage;
                string lexicon;
                string lexiconTH = @"<lexicon uri=""https://cvoiceprodsea.blob.core.windows.net/acc-public-files/734362b8fc124b8d8004d835650d4212/9dd087d8-4859-4096-b788-8f7cf14c4d08.xml?skoid=85130dbe-2390-4897-a9e9-5c88bb59daff&amp;sktid=33e01921-4d64-4f8c-a055-5bdaffd5e33d&amp;skt=2024-09-05T17%3A19%3A47Z&amp;ske=2024-09-11T17%3A24%3A47Z&amp;sks=b&amp;skv=2023-11-03&amp;sv=2023-11-03&amp;st=2024-09-05T17%3A19%3A47Z&amp;se=2024-09-06T17%3A24%3A47Z&amp;sr=b&amp;sp=r&amp;sig=JwiMnRVweFQqBi77YfgGF%2FkLN8c3Bx54ty1Db0DfbGY%3D"" />";
                string lexiconEN = @"<lexicon uri=""https://crchrstoragedev.blob.core.windows.net/thaipbsdev/lexiconen.xml"" />";
                if (inputModel.Languagedata == "th-TH")
                {
                    lexicon = lexiconTH;
                }
                else 
                {
                    lexicon = lexiconEN;
                }

                //if (inputModel.ListAlias != null && inputModel.ListAlias.Count() != 0)
                //{
                //    foreach (var alias in inputModel.ListAlias)
                //    {
                //        if (!string.IsNullOrEmpty(alias.TextToMap) && !string.IsNullOrEmpty(alias.Alias))
                //        {
                //            AliasMessage = AliasMessage.Replace(alias.TextToMap,
                //                $"<sub alias='{alias.Alias}'>{alias.TextToMap}</sub>");
                //        }
                //    }
                //}

                var subscriptionKey = "6654d23c64f6449faf74a7a07740fd95";
                var region = "southeastasia";

                var config = SpeechConfig.FromSubscription(subscriptionKey, region);
                if (inputModel.LanguageSecond == "NoppornNeural")
                {

                    config.EndpointId = "95df2c2f-dffb-4b75-b9cf-00642fac6a3d";
                    config.SpeechSynthesisVoiceName = "NoppornNeural";
                    config.SetSpeechSynthesisOutputFormat(SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3);
                } 
                else if (inputModel.LanguageSecond == "NoppornV2Neural") 
                {
                    config.EndpointId = "2f35a0d2-7516-45d5-a84c-3d8d88a5d8a9";
                    config.SpeechSynthesisVoiceName = "NoppornV2Neural";
                    config.SetSpeechSynthesisOutputFormat(SpeechSynthesisOutputFormat.Audio24Khz160KBitRateMonoMp3);
                }

                string requestdata = "<speak version='1.0' xml:lang='" + inputModel.Languagedata + "'><voice xml:lang='" + inputModel.Languagedata + "' xml:gender='" + inputModel.Gender + "' name='" + inputModel.LanguageSecond + "'>" + lexicon + AliasMessage +
    "</voice></speak>";


                //string requestdata = $@"
                //<speak version='1.0' xml:lang='{inputModel.Languagedata}'>
                //  <voice xml:lang='{inputModel.Languagedata}' xml:gender='{inputModel.Gender}' name='{inputModel.LanguageSecond}'>
                //    <prosody pitch='+10%' rate='-10%'>
                //      {lexicon}{AliasMessage}
                //    </prosody>
                //  </voice>
                //</speak>";

                //string requestdata = $@"
                //<speak version='1.0' xml:lang='{inputModel.Languagedata}'>
                //  <voice xml:lang='{inputModel.Languagedata}' xml:gender='{inputModel.Gender}' name='{inputModel.LanguageSecond}'>
                //    <prosody pitch='+20%' >
                //      {lexicon}{AliasMessage}
                //    </prosody>
                //  </voice>
                //</speak>";

                //string requestdata = $@"
                //<speak version='1.0' xml:lang='{inputModel.Languagedata}'>
                //  <voice xml:lang='{inputModel.Languagedata}' xml:gender='{inputModel.Gender}' name='{inputModel.LanguageSecond}'>
                //    <prosody pitch='-20%' >
                //      {lexicon}{AliasMessage}
                //    </prosody>
                //  </voice>
                //</speak>";

                using var audioStream = AudioOutputStream.CreatePullStream();
                using var synthesizer = new SpeechSynthesizer(config, AudioConfig.FromStreamOutput(audioStream));


                List<TextSegments> textSegments = new List<TextSegments>();

                synthesizer.WordBoundary += (s, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Text))
                    {
                        TimeSpan startTime = TimeSpan.FromTicks((long)e.AudioOffset);
                        TimeSpan endTime = startTime + e.Duration;

                        var segment = new TextSegments
                        {
                            Text = e.Text,
                            StartTime = startTime.TotalSeconds,
                            EndTime = endTime.TotalSeconds
                        };

                        textSegments.Add(segment);
                    }
                    else
                    {
                        Console.WriteLine("Warning: Text is null or empty at this boundary.");
                    }
                };


                var result = await synthesizer.SpeakSsmlAsync(requestdata);

                if (result.Reason == ResultReason.Canceled)
                {
                    var cancellation = SpeechSynthesisCancellationDetails.FromResult(result);
                    return BadRequest(new { Message = cancellation.Reason });
                }


                var bloblink = await ImageHandler.UploadBase64File(result.AudioData);

                var ByteTextSegments = JsonSerializer.SerializeToUtf8Bytes(textSegments, _options);
                string jsonStringObjSegments = System.Text.Encoding.UTF8.GetString(ByteTextSegments);

                var ByteAlias = JsonSerializer.SerializeToUtf8Bytes(inputModel.ListAlias, _options);
                string jsonStringObjAlias = System.Text.Encoding.UTF8.GetString(ByteAlias);


                var addmodel = new TextToSpeechDTO()
                {
                    Url = bloblink.ToString(),
                    Text = inputModel.RequestMessage,
                    ObjSegments = jsonStringObjSegments,
                    Title = "TTS-" + inputModel.Languagedata + "-" + inputModel.Title,
                    TextSSML = AliasMessage,
                    ObjAlias = jsonStringObjAlias
                };

                var returnlink = await _textToSpeechService.AddTextToSpeech(addmodel);
                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful, Data = returnlink });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }

        [HttpPost("AddSpeechToTextTemp")]
        public async Task<IActionResult> AddSpeechToTextTemp([FromForm] RequestMethodSpeechToTextDTO inputModel)
        {
            try
            {
                // Check if a file has been uploaded
                if (inputModel.AudioFile == null || inputModel.AudioFile.Length == 0)
                    return BadRequest("No audio file uploaded.");

                // Ensure the file is a valid audio file (you can check extension or content type)
                var allowedExtensions = new[] { ".wav", ".mp3" };
                var fileExtension = Path.GetExtension(inputModel.AudioFile.FileName);
                if (!allowedExtensions.Contains(fileExtension.ToLower()))
                {
                    return BadRequest("Invalid file type. Only WAV and MP3 files are supported.");
                }

                var filePath = Path.GetTempFileName();  // Temporary file path

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await inputModel.AudioFile.CopyToAsync(stream);  // Save the uploaded audio to the file system

                }

                byte[] fileBytes;
                using (var memoryStream = new MemoryStream())
                {
                    await inputModel.AudioFile.CopyToAsync(memoryStream);  
                    fileBytes = memoryStream.ToArray(); 
                }


                var bloblink = await ImageHandler.UploadBase64File(fileBytes);


                var config = SpeechConfig.FromSubscription("6654d23c64f6449faf74a7a07740fd95", "southeastasia");
                config.SpeechRecognitionLanguage = inputModel.Languagedata;
                config.OutputFormat = OutputFormat.Detailed;

                List<TextSegments> allSegments = new List<TextSegments>();
                string fullText = string.Empty; 

                // Using the audio input file for recognition
                using (var audioInput = AudioConfig.FromWavFileInput(filePath))
                {
                    using (var recognizer = new SpeechRecognizer(config, audioInput))
                    {
                        var result = await recognizer.RecognizeOnceAsync();

                        // Handle the recognized speech result
                        if (result.Reason == ResultReason.RecognizedSpeech)
                        {
                            fullText = result.Text;  // Save the full text of the recognized speech

                            var jsonResult = result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
                            var detailedResult = JsonSerializer.Deserialize<DetailedResultDTO>(jsonResult);

                            // Extract segments from the detailed result
                            var segments = detailedResult.NBest[0].Words.Select(word => new TextSegments
                            {
                                Text = word.Word,
                                StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
                                EndTime = (word.Offset + word.Duration) / 10_000_000.0,
                                Confidence = word.Confidence
                            }).ToList();

                            allSegments.AddRange(segments);
                        }
                        else if (result.Reason == ResultReason.NoMatch)
                        {
                            return BadRequest("No speech could be recognized.");
                        }
                        else if (result.Reason == ResultReason.Canceled)
                        {
                            var cancellation = CancellationDetails.FromResult(result);
                            return BadRequest($"Speech recognition canceled: {cancellation.ErrorDetails}");
                        }
                    }
                }

                // Optionally delete the temp file after processing
                if (System.IO.File.Exists(filePath))
                {
                    System.IO.File.Delete(filePath);
                }

                // Serialize segments to UTF8 JSON
                var byteTextSegments = JsonSerializer.SerializeToUtf8Bytes(allSegments);
                string jsonStringObjSegments = System.Text.Encoding.UTF8.GetString(byteTextSegments);

                // Prepare model for adding to TextToSpeech service
                var addmodel = new TextToSpeechDTO()
                {
                    Url = bloblink.ToString() ?? "",  // If blob storage link is available
                    Text = fullText,  // Use the full recognized text
                    ObjSegments = jsonStringObjSegments,
                    Title = inputModel.Title,
                    TextSSML = " ",
                    ObjAlias = " "
                };

                // Call service to add the data
                var returnLink = await _textToSpeechService.AddTextToSpeech(addmodel);

                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful, Data = returnLink });
            }
            catch (Exception ex)
            {
                // Log the exception and return an error
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }


        [HttpPost("AddSpeechToText")]
        public async Task<IActionResult> AddSpeechToText([FromForm] RequestMethodSpeechToTextDTO inputModel)
        {
            try
            {
                // ตรวจสอบว่าไฟล์ถูกอัปโหลดหรือไม่
                if (inputModel.AudioFile == null || inputModel.AudioFile.Length == 0)
                    return BadRequest("No audio file uploaded.");

                // ตรวจสอบชนิดไฟล์
                var allowedExtensions = new[] { ".wav", ".mp3" };
                var fileExtension = Path.GetExtension(inputModel.AudioFile.FileName);
                if (!allowedExtensions.Contains(fileExtension.ToLower()))
                {
                    return BadRequest("Invalid file type. Only WAV and MP3 files are supported.");
                }

                // สร้างไฟล์ชั่วคราว
                var filePath = Path.GetTempFileName();

                // Copy the audio file to the temporary file
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await inputModel.AudioFile.CopyToAsync(stream);
                }

                string bloblink;
                // Reopen the stream for reading the file content
                using (var fileStream = new FileStream(filePath, FileMode.Open))
                {
                    // Convert the FileStream to byte array
                    byte[] fileBytes;
                    using (var memoryStream = new MemoryStream())
                    {
                        await fileStream.CopyToAsync(memoryStream);
                        fileBytes = memoryStream.ToArray();  // Convert to byte[]
                    }

                    // Now upload the byte array
                     bloblink = (await ImageHandler.UploadBase64File(fileBytes)).ToString();
                }

                // Setup the speech recognition configuration
                var config = SpeechConfig.FromSubscription("6654d23c64f6449faf74a7a07740fd95", "southeastasia");

                //if (true) 
                //{
                //  config.EndpointId = "42d0aa46-f780-4174-af0c-0331864d5e54";
                //}
                config.SpeechRecognitionLanguage = inputModel.Languagedata;

                var fullText = new StringBuilder();
                var allSegments = new List<TextSegments>();

                // Recognize speech from the file
                using (var audioInput = AudioConfig.FromWavFileInput(filePath))
                using (var recognizer = new SpeechRecognizer(config, audioInput))
                {
                    recognizer.Recognized += (s, e) =>
                    {
                        if (e.Result.Reason == ResultReason.RecognizedSpeech)
                        {
                            fullText.Append(e.Result.Text);
                            var jsonResult = e.Result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
                            var detailedResult = JsonSerializer.Deserialize<SpeechRecognitionResultDTO>(jsonResult);

                            var segment = new TextSegments
                            {
                                Text = detailedResult.DisplayText,
                                StartTime = detailedResult.Offset / 10_000_000.0,
                                EndTime = (detailedResult.Offset + detailedResult.Duration) / 10_000_000.0,
                                Confidence = 1.0
                            };

                            allSegments.Add(segment);
                        }
                        else if (e.Result.Reason == ResultReason.NoMatch)
                        {
                            Console.WriteLine("No speech recognized.");
                        }
                    };

                    recognizer.Canceled += (s, e) =>
                    {
                        Console.WriteLine($"CANCELED: Reason={e.Reason}");

                        if (e.Reason == CancellationReason.Error)
                        {
                            Console.WriteLine($"CANCELED: ErrorCode={e.ErrorCode}");
                            Console.WriteLine($"CANCELED: ErrorDetails={e.ErrorDetails}");
                        }
                    };

                    await recognizer.StartContinuousRecognitionAsync();
                    var audioLengthInSeconds = new AudioFileReader(filePath).TotalTime.TotalSeconds;
                    await Task.Delay(TimeSpan.FromSeconds(audioLengthInSeconds + 5)); // Add a buffer for processing

                    await recognizer.StopContinuousRecognitionAsync();
                }

                // Clean up the temporary file
                if (System.IO.File.Exists(filePath))
                {
                    System.IO.File.Delete(filePath);
                }
                var fullTextToChange = fullText.ToString().ToLower();
                if(inputModel.Languagedata == "en-US")
                {
                    var lexicondata = (await _unitOfWork.Lexicon.GetByCondition(x => x.Language == "English")).ToList();
                    foreach (var lexicon in lexicondata) {
                        fullText = fullText.Replace(lexicon.LexiconName, lexicon.LexiconRewrite);
                        foreach (var segmentitem in allSegments)
                        {
                            segmentitem.Text = segmentitem.Text.Replace(lexicon.LexiconName, lexicon.LexiconRewrite);
                        }
                    }
                }
                else
                {
                    var lexicondata = (await _unitOfWork.Lexicon.GetByCondition(x => x.Language == "Thai")).ToList();
                    foreach (var lexicon in lexicondata)
                    {
                        fullText = fullText.Replace(lexicon.LexiconName, lexicon.LexiconRewrite);
                        foreach (var segmentitem in allSegments)
                        {
                            segmentitem.Text = segmentitem.Text.Replace(lexicon.LexiconName, lexicon.LexiconRewrite);
                        }
                    }
                }
               
                var ByteTextSegments = JsonSerializer.SerializeToUtf8Bytes(allSegments, _options);
                string jsonStringObjSegments = System.Text.Encoding.UTF8.GetString(ByteTextSegments);

                // Prepare model for adding to TextToSpeech service
                var addmodel = new TextToSpeechDTO()
                {
                    Url = bloblink.ToString() ?? "",
                    Text = fullText.ToString(),
                    ObjSegments = jsonStringObjSegments,
                    Title = "STT-"+ inputModel.Languagedata + "-"+inputModel.Title,
                    TextSSML = " ",
                    ObjAlias = " ",
                    Language = inputModel.Languagedata,
                };

                var returnLink = await _textToSpeechService.AddTextToSpeech(addmodel);

                return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful, Data = returnLink });
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }


        [HttpPost("AddSpeechToText3")]
        public async Task<IActionResult> AddSpeechToText3([FromForm] RequestMethodSpeechToTextDTO inputModel)
        {
            try
            {
                // ตรวจสอบว่าไฟล์ถูกอัปโหลดหรือไม่
                if (inputModel.AudioFile == null || inputModel.AudioFile.Length == 0)
                    return BadRequest("No audio file uploaded.");

                // ตรวจสอบชนิดไฟล์
                var allowedExtensions = new[] { ".wav", ".mp3" };
                var fileExtension = Path.GetExtension(inputModel.AudioFile.FileName);
                if (!allowedExtensions.Contains(fileExtension.ToLower()))
                {
                    return BadRequest("Invalid file type. Only WAV and MP3 files are supported.");
                }

                // ใช้ Stream เพื่อส่งข้อมูลเสียงไปยัง Speech SDK
                using (var memoryStream = new MemoryStream())
                {
                    await inputModel.AudioFile.CopyToAsync(memoryStream);  // เก็บข้อมูลไฟล์เสียงลงใน MemoryStream
                    memoryStream.Position = 0;  // ตั้งตำแหน่งของ stream กลับไปที่จุดเริ่มต้น

                    var config = SpeechConfig.FromSubscription("6654d23c64f6449faf74a7a07740fd95", "southeastasia");
                    config.SpeechRecognitionLanguage = inputModel.Languagedata;

                    var audioInputStream = AudioInputStream.CreatePushStream();
                    audioInputStream.Write(memoryStream.ToArray());  // เขียนข้อมูลลงใน PushStream
                    audioInputStream.Close();  // ปิด Stream เมื่อเสร็จสิ้น

                    using (var recognizer = new SpeechRecognizer(config, AudioConfig.FromStreamInput(audioInputStream)))
                    {
                        var result = await recognizer.RecognizeOnceAsync();

                        if (result.Reason == ResultReason.RecognizedSpeech)
                        {
                            return Ok(new { RecognizedText = result.Text });
                        }
                        else if (result.Reason == ResultReason.NoMatch)
                        {
                            return BadRequest("No speech could be recognized.");
                        }
                        else
                        {
                            return BadRequest($"Recognition failed: {result.Reason}");
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

    }
}
