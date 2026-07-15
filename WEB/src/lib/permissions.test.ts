import { describe, expect, it } from "vitest";
import { getAllowedNavigation, canAccessRoute } from "./permissions";

describe("role navigation permissions", () => {
  it("exposes all research demo areas to an admin", () => {
    expect(getAllowedNavigation(["Admin"]).map((item) => item.path)).toEqual([
      "/dashboard",
      "/accounts",
      "/journal-entries",
      "/periods",
      "/reports",
      "/audit-logs",
      "/users",
      "/research-evidence",
    ]);
  });

  it("keeps auditors on read-only evidence and report surfaces", () => {
    expect(getAllowedNavigation(["Auditor"]).map((item) => item.path)).toEqual([
      "/dashboard",
      "/accounts",
      "/periods",
      "/reports",
      "/audit-logs",
      "/research-evidence",
    ]);
    expect(canAccessRoute(["Auditor"], "/journal-entries")).toBe(false);
    expect(canAccessRoute(["Auditor"], "/users")).toBe(false);
  });

  it("allows finance managers to work journals and reports but not users or audit logs", () => {
    expect(canAccessRoute(["FinanceManager"], "/journal-entries")).toBe(true);
    expect(canAccessRoute(["FinanceManager"], "/reports")).toBe(true);
    expect(canAccessRoute(["FinanceManager"], "/users")).toBe(false);
    expect(canAccessRoute(["FinanceManager"], "/audit-logs")).toBe(false);
  });
});
