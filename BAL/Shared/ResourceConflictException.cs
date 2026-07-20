namespace BAL.Shared
{
    public sealed class ResourceConflictException : Exception
    {
        public ResourceConflictException(string message) : base(message)
        {
        }
    }
}
