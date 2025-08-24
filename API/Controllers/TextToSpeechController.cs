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

namespace API.Controllers
{
    [Produces("application/json")]
    [ApiController]
    [Route("api/v{version:apiVersion}/[controller]")]
    [ApiVersion("1")]
   // [Authorize]
    public class TextToSpeechController : ControllerBase
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly ITextToSpeechService _textToSpeechService;
        public TextToSpeechController(IUnitOfWork unitOfWork, ITextToSpeechService textToSpeechService)
        {
           _unitOfWork = unitOfWork;
            _textToSpeechService = textToSpeechService;
        }
        [HttpGet("GetTextToSpeechHistory")]
        public async Task<IActionResult> GetTextToSpeechHistory()
        {
            try
            {
                var returndata = await _unitOfWork.TextToSpeechHistory.GetByCondition(x=>x.ActiveFlag);
                List<ResponseHistoryDTO> list = new List<ResponseHistoryDTO>();
                
                foreach (var item in returndata)
                {
                    var segment =new List<TextSegments>();
                    var alias = new List<TextAlias>();
                    try
                    {
                        if (!string.IsNullOrEmpty(item.ObjSegments))
                    {
                        segment = JsonSerializer.Deserialize<List<TextSegments>>(item.ObjSegments, _options);
                    }
                    }
                    catch (Exception ex)
                    {

                    }
                    try
                    {
                        if (!string.IsNullOrEmpty(item.ObjAlias))
                    {
                        alias = JsonSerializer.Deserialize<List<TextAlias>>(item.ObjAlias, _options);
                    }
                        }
                        catch (Exception ex)
                        {

                        }
                        var reslist = new ResponseHistoryDTO()
                    {
                        TextToSpeechID = item.TextToSpeechID,
                        Url = item.Url,
                        Text = item.Text,
                        Title = item.Title,
                        CreatedAt = item.CreatedAt,
                        UpdatedAt = item.UpdatedAt,
                        ActiveFlag = item.ActiveFlag,
                        SegmentList = segment,
                        AliasList = alias,
                        Language = item.Language,
                    };
                    list.Add(reslist);
                }
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = list });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
        //[HttpPost("AddTextToSpeech")]
        //public async Task<IActionResult> AddTextToSpeech(TextToSpeechDTO inputModel)
        //{
        //    try
        //    {
        //       var returndata =  await _textToSpeechService.AddTextToSpeech(inputModel);
        //        return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful, Data = returndata });
        //    }
        //    catch (Exception ex)
        //    {
        //        return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
        //    }
        //}
        [HttpGet("GetTextToSpeechHistoryByID")]
        public async Task<IActionResult> GetTextToSpeechHistoryByID(Guid TextToSpeechID)
        {
            try
            {
                var returndata = new ResponseHistoryDTO();
                var segment = new List<TextSegments>();
                var alias = new List<TextAlias>();
                var speechdata = (await _unitOfWork.TextToSpeechHistory.GetByCondition(x=>x.TextToSpeechID == TextToSpeechID)).FirstOrDefault();
                if(speechdata != null)
                {
                    //var segments = detailedResult.NBest[0].Words.Select(word => new TextSegments
                    //{
                    //    Text = word.Word,
                    //    StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
                    //    EndTime = (word.Offset + word.Duration) / 10_000_000.0,
                    //    Confidence = word.Confidence
                    //}).ToList();
                    try
                    {
                        if (!string.IsNullOrEmpty(speechdata.ObjSegments))
                        {
                            segment = JsonSerializer.Deserialize<List<TextSegments>>(speechdata.ObjSegments, _options);
                        }
                    }
                    catch (Exception ex) 
                    {
                       
                    }
                    try
                    {
                        if (!string.IsNullOrEmpty(speechdata.ObjAlias))
                    {
                        alias = JsonSerializer.Deserialize<List<TextAlias>>(speechdata.ObjAlias, _options);
                    }
                    }
                    catch (Exception ex)
                    {

                    }

                    returndata.TextToSpeechID = speechdata.TextToSpeechID;
                    returndata.Url = speechdata.Url;
                    returndata.Text = speechdata.Text;
                    returndata.Title = speechdata.Title;
                    returndata.CreatedAt = speechdata.CreatedAt;
                    returndata.UpdatedAt = speechdata.UpdatedAt;
                    returndata.ActiveFlag = speechdata.ActiveFlag;
                    returndata.SegmentList = segment;
                    returndata.AliasList = alias;
                    returndata.Language = speechdata.Language;
                }
                return Ok(new ResponseModel { Message = Messages.Successfully, Status = APIStatus.Successful, Data = returndata });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }

        [HttpGet("GetToken")]
        public async Task<IActionResult> Getvoicelist()
        {

            using (var client = new HttpClient())
            {
                client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", "6654d23c64f6449faf74a7a07740fd95");
                client.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/x-www-form-urlencoded"));
                UriBuilder uriBuilder = new UriBuilder("https://southeastasia.api.cognitive.microsoft.com/sts/v1.0/issueToken");

                var result = await client.PostAsync(uriBuilder.Uri.AbsoluteUri, null);
                Console.WriteLine("Token Uri: {0}", uriBuilder.Uri.AbsoluteUri);
                var returndata = await result.Content.ReadAsStringAsync();

                return Ok(new { data = returndata });
            }

        }
        [HttpPost("AddTextToSpeech")]
        public async Task<IActionResult> AddTextToSpeech(RequestMethodDTO inputModel)
        {
            try
            {
                var token = string.Empty;
                using (var client = new HttpClient())
                {
                    client.DefaultRequestHeaders.Add("Ocp-Apim-Subscription-Key", "6654d23c64f6449faf74a7a07740fd95");
                    client.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/x-www-form-urlencoded"));
                    UriBuilder uriBuilder = new UriBuilder("https://southeastasia.api.cognitive.microsoft.com/sts/v1.0/issueToken");

                    var result = await client.PostAsync(uriBuilder.Uri.AbsoluteUri, null);
                    Console.WriteLine("Token Uri: {0}", uriBuilder.Uri.AbsoluteUri);
                    token = await result.Content.ReadAsStringAsync();

                    //  return Ok(new { data = returndata });
                }
                using (var client = new HttpClient())
                {
                    client.DefaultRequestHeaders.Add("Authorization", "Bearer " + token);
                    // client.DefaultRequestHeaders.Add("Content-Type", "application/ssml+xml;charset=utf-8");
                    client.DefaultRequestHeaders.Accept.Add(new System.Net.Http.Headers.MediaTypeWithQualityHeaderValue("application/ssml+xml"));

                    // client.DefaultRequestHeaders.Add("X-Microsoft-OutputFormat", "audio-16khz-32kbitrate-mono-mp3");
                    client.DefaultRequestHeaders.Add("X-Microsoft-OutputFormat", "riff-8khz-8bit-mono-alaw");
                    client.DefaultRequestHeaders.Add("User-Agent", "speechtotextapi");
                    UriBuilder uriBuilder = new UriBuilder("https://southeastasia.tts.speech.microsoft.com/cognitiveservices/v1");
                    // UriBuilder uriBuilder = new UriBuilder("https://southeastasia.customvoice.api.speech.microsoft.com");

                    //th-TH-NiwatNeural en-US-ChristopherNeural
                    string requestdata = "<speak version='1.0' xml:lang='" + inputModel.Languagedata + "'><voice xml:lang='" + inputModel.Languagedata + "' xml:gender='" + inputModel.Gender + "' name='" + inputModel.LanguageSecond + "'>" + inputModel.RequestMessage.ToString() +
                        "</voice></speak>";


                    var result = await client.PostAsync(uriBuilder.Uri.AbsoluteUri, new StringContent(requestdata, Encoding.UTF8, "application/ssml+xml"));
                    Console.WriteLine("Test Uri: {0}", uriBuilder.Uri.AbsoluteUri);

                    var returndata = await result.Content.ReadAsByteArrayAsync();

                    //var newtest = Convert.ToBase64String(returndata);
                    //byte[] output = new byte[returndata.Length / 2];
                    //int outputIndex = 0;
                    //for (int n = 0; n < returndata.Length; n += 4)
                    //{
                    //    int leftChannel = BitConverter.ToInt16(returndata, n);
                    //    int rightChannel = BitConverter.ToInt16(returndata, n + 2);
                    //    int mixed = (leftChannel + rightChannel) / 2;
                    //    byte[] outSample = BitConverter.GetBytes((short)mixed);

                    //    // copy in the first 16 bit sample
                    //    output[outputIndex++] = outSample[0];
                    //    output[outputIndex++] = outSample[1];
                    //}

                    var bloblink = await ImageHandler.UploadBase64File(returndata);

                    var addmodel = new TextToSpeechDTO()
                    {
                        Url = bloblink.ToString(),
                        Text = inputModel.RequestMessage,
                        ObjSegments = await GetSegments(bloblink.ToString(), inputModel.Languagedata),
                        Title = inputModel.Title,
                        Language = inputModel.Languagedata
                    };
                    var returnlink = await _textToSpeechService.AddTextToSpeech(addmodel);
                    return Ok(new ResponseModel { Message = Messages.AddSucess, Status = APIStatus.Successful, Data = returnlink });
                }
            }
            catch (Exception ex)
            {

                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }

        }

        [HttpPost("UpdateTextToSpeech")]
        public async Task<IActionResult> UpdateTextToSpeech(ResponseHistoryDTO inputModel)
        {
            try
            {
                await _textToSpeechService.UpdateTextToSpeech(inputModel);

                return Ok(new ResponseModel { Message = Messages.UpdateSucess, Status = APIStatus.Successful });
            }
            catch (Exception ex)
            {

                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }

        }


        //[HttpGet("Segments")]
        //public async Task<IActionResult> GetSetments(string audiolink)
        //{
        //    try
        //    {
        //        var testing = string.Empty;
        //        var localfile =await DownloadAudioFileAsync(audiolink);
        //        var config = SpeechConfig.FromSubscription("6654d23c64f6449faf74a7a07740fd95", "southeastasia");
        //        config.SpeechRecognitionLanguage = "en-US";
        //        config.OutputFormat = OutputFormat.Detailed;
        //        List<TextSegment> allSegments = new List<TextSegment>();
        //       // var localfile = "C:\\Users\\hlain\\source\\repos\\Web-API\\API\\output-en.wav";
        //        using (var audioInput = AudioConfig.FromWavFileInput(localfile))
        //        {
        //            using (var recognizer = new SpeechRecognizer(config, audioInput))
        //            {
        //                var result = await recognizer.RecognizeOnceAsync();
        //                if (result.Reason == ResultReason.RecognizedSpeech)
        //                {
        //                    var jsonResult = result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
        //                   // testing = result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
        //                    var detailedResult = JsonSerializer.Deserialize<DetailedResult>(jsonResult);

        //                    var segments = detailedResult.NBest[0].Words.Select(word => new TextSegment
        //                    {
        //                        Text = word.Word,
        //                        StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
        //                        EndTime = (word.Offset + word.Duration) / 10_000_000.0,
        //                        Confidence = word.Confidence
        //                    }).ToList();

        //                    allSegments.AddRange(segments);
        //                    Console.WriteLine($"We recognized: {result.Text}");
        //                   // testing = result.Text;
        //                }
        //                else if (result.Reason == ResultReason.NoMatch)
        //                {
        //                    Console.WriteLine($"NOMATCH: Speech could not be recognized.");
        //                }
        //                else if (result.Reason == ResultReason.Canceled)
        //                {
        //                    var cancellation = CancellationDetails.FromResult(result);
        //                    Console.WriteLine($"CANCELED: Reason={cancellation.Reason}");
        //                    if (cancellation.Reason == CancellationReason.Error)
        //                    {
        //                        Console.WriteLine($"CANCELED: ErrorCode={cancellation.ErrorCode}");
        //                        Console.WriteLine($"CANCELED: ErrorDetails={cancellation.ErrorDetails}");
        //                        Console.WriteLine($"CANCELED: Did you update the subscription info?");
        //                    }
        //                }
        //            }
        //        }
        //        return Ok(new { data = allSegments });
        //    }
        //    catch (Exception)
        //    {

        //        throw;
        //    }
        //}

        static async Task<string> GetSegments(string audiolink, string language)
        {
            try
            {
                var testing = string.Empty;
                var localfile = await DownloadAudioFileAsync(audiolink);
                var config = SpeechConfig.FromSubscription("6654d23c64f6449faf74a7a07740fd95", "southeastasia");
                config.SpeechRecognitionLanguage = language;
                config.OutputFormat = OutputFormat.Detailed;
                List<TextSegments> allSegments = new List<TextSegments>();
                // var localfile = "C:\\Users\\hlain\\source\\repos\\Web-API\\API\\output-en.wav";
                using (var audioInput = AudioConfig.FromWavFileInput(localfile))
                {
                    using (var recognizer = new SpeechRecognizer(config, audioInput))
                    {
                        var result = await recognizer.RecognizeOnceAsync();
                        if (result.Reason == ResultReason.RecognizedSpeech)
                        {
                            testing = result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
                            // testing = result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
                            var detailedResult = JsonSerializer.Deserialize<DetailedResultDTO>(testing);
                           
                            var segments = detailedResult.NBest[0].Words.Select(word => new TextSegments
                            {
                                Text = word.Word,
                                StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
                                EndTime = (word.Offset + word.Duration) / 10_000_000.0,
                                Confidence = word.Confidence
                            }).ToList();

                            var resultbite = JsonSerializer.SerializeToUtf8Bytes(segments, _options);
                             testing =  System.Text.Encoding.UTF8.GetString(resultbite);
                            //var segments = detailedResult.NBest[0].Words.Select(word => new TextSegment
                            //{
                            //    Text = word.Word,
                            //    StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
                            //    EndTime = (word.Offset + word.Duration) / 10_000_000.0,
                            //    Confidence = word.Confidence
                            //}).ToList();

                            allSegments.AddRange(segments);
                            Console.WriteLine($"We recognized: {result.Text}");
                            // testing = result.Text;
                        }
                        else if (result.Reason == ResultReason.NoMatch)
                        {
                            Console.WriteLine($"NOMATCH: Speech could not be recognized.");
                        }
                        else if (result.Reason == ResultReason.Canceled)
                        {
                            var cancellation = CancellationDetails.FromResult(result);
                            Console.WriteLine($"CANCELED: Reason={cancellation.Reason}");
                            if (cancellation.Reason == CancellationReason.Error)
                            {
                                Console.WriteLine($"CANCELED: ErrorCode={cancellation.ErrorCode}");
                                Console.WriteLine($"CANCELED: ErrorDetails={cancellation.ErrorDetails}");
                                Console.WriteLine($"CANCELED: Did you update the subscription info?");
                            }
                        }
                    }
                }
                return testing;
            }
            catch (Exception)
            {

                throw;
            }
        }



        static readonly JsonSerializerOptions _options = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true,
        };
        //[HttpGet("SegmentsTwo")]
        //public async Task<IActionResult> GetSetmentsTwo(string audiolink)
        //{
        //    try
        //    {
        //        var testing = string.Empty;
        //        var subscriptionKey = "6654d23c64f6449faf74a7a07740fd95";
        //        var region = "southeastasia";
        //        var audioFilePath = "C:\\Users\\hlain\\source\\repos\\Web-API\\API\\output-en.wav";

        //        var speechConfig = SpeechConfig.FromSubscription(subscriptionKey, region);
        //        speechConfig.SpeechRecognitionLanguage = "en-US";
        //        var audioConfig = AudioConfig.FromWavFileInput(audioFilePath);

        //        // ตั้งค่าให้ Output เป็น JSON
        //        speechConfig.OutputFormat = OutputFormat.Detailed;

        //        var recognizer = new SpeechRecognizer(speechConfig, audioConfig);
        //        await recognizer.StartContinuousRecognitionAsync();
        //        List<TextSegment> allSegments = new List<TextSegment>();
        //        string TempString = "";
        //        recognizer.Recognized += (s, e) =>
        //        {

        //            if (e.Result.Reason == ResultReason.RecognizedSpeech)
        //            {
        //                var jsonResult = e.Result.Properties.GetProperty(PropertyId.SpeechServiceResponse_JsonResult);
        //                var detailedResult = JsonSerializer.Deserialize<DetailedResult>(jsonResult);

        //                var segments = detailedResult.NBest[0].Words.Select(word => new TextSegment
        //                {
        //                    Text = word.Word,
        //                    StartTime = word.Offset / 10_000_000.0,  // Convert ticks to seconds
        //                    EndTime = (word.Offset + word.Duration) / 10_000_000.0,
        //                    Confidence = word.Confidence
        //                }).ToList();

        //                allSegments.AddRange(segments);
        //            }
        //            else if (e.Result.Reason == ResultReason.NoMatch)
        //            {
        //                Console.WriteLine("No speech could be recognized.");
        //            }
        //        };

        //        recognizer.SessionStopped += (s, e) =>
        //        {
        //            Console.WriteLine("Session stopped.");
        //            recognizer.StopContinuousRecognitionAsync().Wait();

        //            // Show all collected text segments
        //            foreach (var segment in allSegments)
        //            {
        //                //Console.WriteLine($"Text: {segment.Text}, Start: {segment.StartTime}, End: {segment.EndTime}, Confidence: {segment.Confidence}");
        //                TempString = TempString + ",{" + $"Text: {segment.Text}, Start: {segment.StartTime}, End: {segment.EndTime}, Confidence: {segment.Confidence}" + "}";
        //            }
        //            Console.WriteLine(TempString);
        //        };

        //        // Stop recognition
        //        await recognizer.StopContinuousRecognitionAsync();
        //        return Ok(new { data = allSegments });
        //    }
        //    catch (Exception)
        //    {

        //        throw;
        //    }
        //}
        static async Task<string> DownloadAudioFileAsync(string url)
        {
            using (HttpClient client = new HttpClient())
            {
                var response = await client.GetAsync(url);
                response.EnsureSuccessStatusCode();

                var tempFile = Path.GetTempFileName();
                await using (var fs = new FileStream(tempFile, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    await response.Content.CopyToAsync(fs);
                }

                return tempFile;
            }
        }

        [HttpPost("TryAgain")]

        public async Task<IActionResult> TryAgain()
        {
            try
            {
                // string TextInput = "A former mayor of the Rachibori Provincial administrative organization, Pio, Vivat Nita Kanchina was ahead of his rival from the People's Party, Chirat Sakhisarupong, by a wide margin in the mayoral election at about 8:00 PM. According to the unofficial and incomplete vote count, Vivat had 200 and 5057 votes against Charat's 142,581 after about half of the ballots have been counted. While not a member, Vivat is supported by the Few Thai Party. Upon realizing that he was leading by about 60,000 votes, Vivat thanked the people of Ratchaburi for their support and vowed to carry on with his unfinished work in the province. Election Commission Chairman it the **** bun Breaking told the media this evening that he is satisfied with the voter turnout, which is expected to be about 75% compared to 68% four years ago. He said that the election was running smoothly and no irregularities have been reported so far. He instructed election officials at the provinces 1149 polling units to count the ballots 1 by 1 so the people can see clearly to ensure transparency. Earlier, he predicted the unofficial poll result would be known at about 8:00 PM. It is now looking more likely. Between 9:00 PM and 10:00 PM. A former mayor of the Rachibori Provincial Administrative Organization, Pao Vivat Nitikanchina, was ahead of his rival from the People's Party, Chirat Sakhisarupang, by a wide margin in the mayoral election. At about 8:00 PM, according to the unofficial and incomplete vote count, Vivat had 200 and 5057 votes against Charat's 142,581 after about half of the ballots had been counted. Remember, Vivat is supported by the Few Thai Party. Upon realizing that he was leading by about 60,000 votes, Vivat thanked the people of Ratchaburi for their support and vowed to carry on with his unfinished work in the province. Election Commission Chairman Ithaporn Bun Praking told the media this evening that he is satisfied with the voter turn out, which is expected to be about 75% compared to 68% four years ago. He said that the election was running smoothly and no irregularities have been reported so far. He instructed election officials at the province's 1149 polling units to count the ballots 1 by 1 so the people can see clearly to ensure transparency. Earlier, he predicted the unofficial poll result would known at about 8:00 PM. It is now looking more likely between 9:00 PM and 10:00 PM.";
                string TextInput = "วันนอร์ ชี้พรรคประชาชาติ ส่งชื่อเดียว \"พ.ต.อ.ทวี สอดส่อง\" เข้า ครม.แพทองธาร ส่วนกระแสเพื่อไทยทวงคืนเก้าอี้ประธานสภาฯ ยันไม่มีแรงกดดัน วันนี้ (22 ส.ค.2567) นายวันมูหะมัดนอร์ มะทา ประธานสภาผู้แทนราษฎร กล่าวถึงการทำงานของฝ่ายนิติบัญญัติ ในช่วงการตั้งคณะรัฐมนตรี (ครม.)ช่วงนี้ว่า การทำงานของฝ่ายนิติบัญญัติ ยังเดินหน้าขับเคลื่อนได้ทุกอย่าง โดยการเสนอร่าง พ.ร.บ.งบประมาณรายจ่ายประจำปี ครม.รักษาการ ยังเสนอมายังสภาพิจารณาได้ ขณะนี้อยู่ระหว่างการพิจารณาของกรรมาธิการ ซึ่งตามกรอบเวลาจะต้องพิจารณาให้แล้วเสร็จภายใน 105 วัน นับแต่วันที่สภารับร่างมา นายวันมูหะมัดนอร์ กล่าวว่า ทางคณะกรรมการบริหารพรรคได้เสนอรายชื่อพ.ต.อ.ทวี สอดส่อง ดำรงตำแหน่งรัฐมนตรีในครม.น.ส.แพทองธาร ชินวัตร ซึ่งหลังจากนี้ นายกรัฐมนตรีจะพิจารณารายชื่อ และแต่งตั้งดำรงตำแหน่งในกระทรวงต่างๆ ก่อนที่จะนำรายชื่อขึ้นเสนอโปรดเกล้าฯ แต่งตั้งต่อไป โดยปฏิเสธรับทราบข้อมูลเกี่ยวกับการเสนอบุคคลเข้าดำรงตำแหน่ง 2 คน โดยชี้ว่าเป็นอำนาจการพิจารณาของคณะกรรมการบริหารพรรคประชาชาติ ซึ่งตนเองนั้นไม่ได้เป็นกรรมการบริหารพรรคด้วย ส่วนตำแหน่งประธานสภาฯ จะมีการปรับเปลี่ยนหรือไม่เป็นเรื่องของสส. กระบวนการด้านนิติบัญญัติไม่เกี่ยวกับฝ่ายบริหาร ส่วนตำแหน่งที่ว่างอยู่ คือตำแหน่งรองประธานสภาฯ คนที่ 1 รอติดตามการนัดฝ่ายค้านและวิปรัฐบาลที่จะหารือ โดยสำนักงานเลขาธิการสภา มีความพร้อมที่จะจัดให้มีการเลือกตำแหน่งรองประธานสภาคนที่1 หากได้รับแจ้ง เพราะต้องแบ่งภาระหน้าที่ของทั้ง 3 คน";
                string blobstring = string.Empty;
                Console.OutputEncoding = System.Text.Encoding.UTF8;
                var subscriptionKey = "6654d23c64f6449faf74a7a07740fd95";
                var region = "southeastasia";
                var config = SpeechConfig.FromSubscription(subscriptionKey, region);
                config.SpeechSynthesisVoiceName = "th-TH-NiwatNeural";
                config.SetProperty(PropertyId.SpeechServiceResponse_RequestWordLevelTimestamps, "true");

                var textSegments = new List<TextSegments>();

                using var synthesizer = new SpeechSynthesizer(config);
                synthesizer.WordBoundary += (s, e) =>
                {
                    TimeSpan startTime = TimeSpan.FromTicks((long)e.AudioOffset);
                    TimeSpan duration = e.Duration;
                    TimeSpan endTime = startTime + duration;

                    var segment = new TextSegments
                    {
                        Text = e.Text,
                        StartTime = startTime.TotalSeconds,
                        EndTime = endTime.TotalSeconds,
                        Confidence = 1.0 // Placeholder value for confidence
                    };

                    textSegments.Add(segment);

                    Console.WriteLine($"Text: {segment.Text}, StartTime: {segment.StartTime}, EndTime: {segment.EndTime}");
                };

                //var result = await synthesizer.SpeakTextAsync(TextInput);
                //if (result.Reason == ResultReason.SynthesizingAudioCompleted)
                //{
                //    Console.WriteLine("Speech synthesis completed.");

                //    // Save the result to a local file
                //    string tempFilePath = Path.Combine(Path.GetTempPath(), System.Guid.NewGuid().ToString() + "output.wav");
                //    using var audioDataStream = AudioDataStream.FromResult(result);
                //    await audioDataStream.SaveToWaveFileAsync(tempFilePath);

                //    // Load the file into a memory stream
                //    using var memoryStream = new MemoryStream();
                //    using (var fileStream = System.IO.File.OpenRead(tempFilePath))
                //    {
                //        await fileStream.CopyToAsync(memoryStream);
                //    }
                //    memoryStream.Position = 0; // Reset the stream position for upload

                //    // Upload to Azure Blob Storage
                //    Uri blobUri = await ImageHandler.UploadFileFromStream(memoryStream, System.Guid.NewGuid().ToString() + "output.wav");
                //    Console.WriteLine("Upload completed.");
                //    Console.WriteLine(blobUri);
                //    blobstring = blobUri.ToString();
                //}
                //else if (result.Reason == ResultReason.Canceled)
                //{
                //    var cancellation = SpeechSynthesisCancellationDetails.FromResult(result);
                //    Console.WriteLine($"CANCELED: Reason={cancellation.Reason}");
                //}
               await Task.Run(async () =>
                {
                    var result = await synthesizer.SpeakTextAsync(TextInput);

                    if (result.Reason == ResultReason.SynthesizingAudioCompleted)
                    {
                        Console.WriteLine("Speech synthesis completed.");

                        // Save the result to a local file
                        string tempFilePath = Path.Combine(Path.GetTempPath(), System.Guid.NewGuid().ToString() + "output.wav");
                        using var audioDataStream = AudioDataStream.FromResult(result);
                        await audioDataStream.SaveToWaveFileAsync(tempFilePath);

                        // Load the file into a memory stream
                        using var memoryStream = new MemoryStream();
                        using (var fileStream = System.IO.File.OpenRead(tempFilePath))
                        {
                            await fileStream.CopyToAsync(memoryStream);
                        }
                        memoryStream.Position = 0; // Reset the stream position for upload

                        // Upload to Azure Blob Storage
                        Uri blobUri = await ImageHandler.UploadFileFromStream(memoryStream, System.Guid.NewGuid().ToString() + "output.wav");
                        Console.WriteLine("Upload completed.");
                        Console.WriteLine(blobUri);
                    }
                    else if (result.Reason == ResultReason.Canceled)
                    {
                        var cancellation = SpeechSynthesisCancellationDetails.FromResult(result);
                        Console.WriteLine($"CANCELED: Reason={cancellation.Reason}");
                    }
                }).ContinueWith(t =>
                {
                    if (t.IsFaulted)
                    {
                        Console.WriteLine($"An error occurred: {t.Exception?.GetBaseException().Message}");
                    }
                });
                return Ok(new ResponseModel { Message = blobstring, Status = APIStatus.Successful, Data = textSegments });
            }
            catch (Exception ex)
            {
                return Ok(new ResponseModel { Message = ex.Message, Status = APIStatus.SystemError });
            }
        }
      
    }
}
