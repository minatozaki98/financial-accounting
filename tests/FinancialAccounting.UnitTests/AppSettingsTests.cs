using FluentAssertions;
using MODEL.ApplicationConfig;
using Xunit;

namespace FinancialAccounting.UnitTests;

public class AppSettingsTests
{
    [Fact]
    public void Defaults_ShouldProvideSecurityAndPerformanceOptions()
    {
        var settings = new AppSettings();

        settings.SecurityHeaders.Should().NotBeNull();
        settings.SecurityHeaders.Enabled.Should().BeTrue();
        settings.PerformanceGates.Should().NotBeNull();
        settings.PerformanceGates.Profile50.MaxErrorPct.Should().Be(0.5);
        settings.PerformanceGates.Profile500.MaxP95Ms.Should().Be(1200);
    }
}
