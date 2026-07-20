using MODEL.DTOs;

namespace BAL.IServices
{
    public interface IBankReconciliationService
    {
        Task<BankReconciliationResultDto> CreateAsync(
            CreateBankReconciliationRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);

        Task<BankReconciliationMatchResultDto> AutoMatchAsync(
            Guid reconciliationId,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);

        Task<BankReconciliationResultDto> ConfirmAsync(
            Guid reconciliationId,
            ConfirmBankReconciliationMatchRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);

        Task<BankReconciliationExceptionsDto> GetExceptionsAsync(
            Guid reconciliationId,
            CancellationToken cancellationToken = default);

        Task<BankReconciliationResultDto> FinalizeAsync(
            Guid reconciliationId,
            FinalizeBankReconciliationRequestDto request,
            Guid actorUserId,
            string? ipAddress,
            CancellationToken cancellationToken = default);
    }
}
