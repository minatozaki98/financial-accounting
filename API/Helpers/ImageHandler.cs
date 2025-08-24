using System.Net;
using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using Azure.Storage;

namespace API.Helpers
{
    public static class ImageHandler
    {
        ////AzureStorageConnection //DEV
        private static readonly string connectionString = "DefaultEndpointsProtocol=https;AccountName=testingdevcrc;AccountKey=BkRXf7jK6WGqFdiNim2UnoC6y6gwqFSMANVA35GUj4f89u7jnUfUYnOzBUdfsXQnrG091sZa0ZuI+AStlb2SAQ==;EndpointSuffix=core.windows.net";
        private static readonly string containerName = "testdev";
        private static readonly string accountKey = "BkRXf7jK6WGqFdiNim2UnoC6y6gwqFSMANVA35GUj4f89u7jnUfUYnOzBUdfsXQnrG091sZa0ZuI+AStlb2SAQ==";

        //AzureStorageConnection //STG Booking
        //private static readonly string connectionString = "DefaultEndpointsProtocol=https;AccountName=aroidedbookingstorage;AccountKey=Ro+A9NuxY+MPTMKgcIpKLy+jjHY+/NZQCn2bUjEApCOTXpb/aaIDIZyCyMQsYt5hrjdqhG+80Cnf+AStrGY4Cg==;EndpointSuffix=core.windows.net";
        //private static readonly string containerName = "uploadedimages";
        //private static readonly string accountKey = "Ro+A9NuxY+MPTMKgcIpKLy+jjHY+/NZQCn2bUjEApCOTXpb/aaIDIZyCyMQsYt5hrjdqhG+80Cnf+AStrGY4Cg==";

        ////AzureStorageConnection //Prod 
        //private static readonly string connectionString = "DefaultEndpointsProtocol=https;AccountName=aroidedpro;AccountKey=SwJ7H6ugyJJAZHVQ9P1m8eSOXbLm8SYUsEyAqcW0sniCBwYm0vnbzj9JehEEr7KG7r5qSCqmT+82+AStUXMTfQ==;EndpointSuffix=core.windows.net";
        //private static readonly string containerName = "uploadedimages";
        //private static readonly string accountKey = "0WsrO7djXNFVUJExEMy35e7ktR8awL6R+ppsZ9pnje+/rHXwkANAuYn05cLvhfqJ4vhO012YCIw6+AStnqUi7A==";

        public static async Task<Uri> UploadImage(IFormFile image)
        {

            var blobServiceClient = new BlobServiceClient(connectionString);
            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var fileName = Path.GetFileNameWithoutExtension(image.FileName) + "_" + System.Guid.NewGuid().ToString() + Path.GetExtension(image.FileName);
            var blobClient = containerClient.GetBlobClient(fileName);
            using (var stream = image.OpenReadStream())
            {
                await blobClient.UploadAsync(stream);
            }
            return blobClient.Uri;
        }

        public static async Task<Uri> UploadFile(IFormFile file)
        {
            var blobServiceClient = new BlobServiceClient(connectionString);
            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var fileName = Path.GetFileNameWithoutExtension(file.FileName) + "_" + System.Guid.NewGuid().ToString() + Path.GetExtension(file.FileName);
            var blobClient = containerClient.GetBlobClient(fileName);
            using (var stream = file.OpenReadStream())
            {
                await blobClient.UploadAsync(stream);
            }
            return blobClient.Uri;
        }

        public static async Task<Uri> UploadBase64File(byte[] base64)
        {
            var blobServiceClient = new BlobServiceClient(connectionString);
            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var fileName = "Text_To_Speech" + "_" + System.Guid.NewGuid().ToString() + "."+"wav";
            var blobClient = containerClient.GetBlobClient(fileName);
           // byte[] byteFile = Convert.FromBase64String(base64);

            using (var stream = new MemoryStream(base64))
            {
                await blobClient.UploadAsync(stream,true);
            }
            return blobClient.Uri;
        }

        public static async Task DeleteImage(string imageName)
        {
            var blobServiceClient = new BlobServiceClient(connectionString);
            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            var blobClient = containerClient.GetBlobClient(imageName);
            if (!blobClient.Exists())
            {

                var errors = new Dictionary<string, string>
                {
                    { "error", $"File '{imageName}' does not exist in the container."}
                };
            }

            await blobClient.DeleteAsync();
        }

       public static async Task<Uri> UploadFileFromStream(Stream stream, string fileName)
        {
            var blobServiceClient = new BlobServiceClient(connectionString);
            var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

            fileName = Path.GetFileNameWithoutExtension(fileName) + "_" + Guid.NewGuid().ToString() + Path.GetExtension(fileName);
            var blobClient = containerClient.GetBlobClient(fileName);

            await blobClient.UploadAsync(stream, overwrite: true);
            return blobClient.Uri;
        }

        //public static string GetSASToken(string fileName)
        //{
        //    string urldata = fileName;
        //    try
        //    {
        //        if (!string.IsNullOrEmpty(fileName))
        //        {
        //            var Filenamesplit = fileName.Split('/');
        //            CloudStorageAccount storageAccount = CloudStorageAccount.Parse(connectionString);
        //            var blobClient = storageAccount.CreateCloudBlobClient();
        //            CloudBlobContainer container = blobClient.GetContainerReference(containerName);
        //            CloudBlockBlob blockBlob = container.GetBlockBlobReference(fileName);
        //            Azure.Storage.Sas.BlobSasBuilder blobSasBuilder = new Azure.Storage.Sas.BlobSasBuilder()
        //            {
        //                BlobContainerName = _appSettings.AzureContainer,
        //                BlobName = Filenamesplit[Filenamesplit.Length - 1],
        //                ExpiresOn = DateTime.UtcNow.AddMonths(1),
        //            };
        //            blobSasBuilder.SetPermissions(Azure.Storage.Sas.BlobSasPermissions.Read);
        //            var sasToken = blobSasBuilder.ToSasQueryParameters(new StorageSharedKeyCredential(_appSettings.AzureStorageAccountName, _appSettings.AzureAccessKey)).ToString();
        //            urldata += "?" + sasToken;
        //        }
        //        return urldata;
        //    }
        //    catch (Exception ex)
        //    {
        //        Console.WriteLine(ex.Message.ToString());
        //        throw;
        //    }
        //}

        public static async Task<string> GenerateSASToken(string blobName, string permissions, int validityPeriodInMinutes)
        {
            // Create a BlobServiceClient using the connection string
            BlobServiceClient blobServiceClient = new BlobServiceClient(connectionString);

            // Get a reference to the container and blob
            BlobContainerClient containerClient = blobServiceClient.GetBlobContainerClient(containerName);
            BlobClient blobClient = containerClient.GetBlobClient(blobName);



            // Create a SharedKeyCredential from the connection string
            StorageSharedKeyCredential credential = new StorageSharedKeyCredential(blobServiceClient.AccountName, accountKey);

            // Create a SAS builder and set the permissions and validity period
            BlobSasBuilder sasBuilder = new BlobSasBuilder
            {
                BlobContainerName = containerName,
                BlobName = blobName,
                Resource = "b",
                StartsOn = DateTimeOffset.UtcNow,
                ExpiresOn = DateTimeOffset.UtcNow.AddMinutes(validityPeriodInMinutes)
            };

            // Set the permissions
            if (permissions.Contains("r"))
            {
                sasBuilder.SetPermissions(BlobContainerSasPermissions.Read);
            }
            if (permissions.Contains("w"))
            {
                sasBuilder.SetPermissions(BlobContainerSasPermissions.Write);
            }
            if (permissions.Contains("d"))
            {
                sasBuilder.SetPermissions(BlobContainerSasPermissions.Delete);
            }

            // Generate the SAS token
            string sasToken = sasBuilder.ToSasQueryParameters(credential).ToString();

            return sasToken;
        }
    }
}
