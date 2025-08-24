using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace MODEL.ApplicationConfig
{
    public class ResponseModel
    {
        public string? Message { get; set; }
        public APIStatus Status { get; set; }
        public object? Data { get; set; }
    }
    public enum APIStatus
    {
        Successful = 0,
        Error = 1,
        SystemError = 2
    }
    public static class Messages
    {
        public const string Successfully = "Successfully";
        public const string UpdateSucess = "Update Successfully";
        public const string DeleteSucess = "Delete Successfully";
        public const string AddSucess = "Add Successfully";
        public const string ErrorWhileFetchingData = "Error while fetching data.";
        public const string InvalidPostedData = "Posted invalid data.";
        public const string NoData = "No data was found";
        public const string Result = "Result Found!";
        public const string UpdateFail = "Updated Fail!";
    }
}
