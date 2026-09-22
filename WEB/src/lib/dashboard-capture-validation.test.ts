import { describe, expect, it } from "vitest";
import { assertNoForbiddenText, validateMetric } from "./dashboard-capture-validation";

describe("dashboard capture validation", () => {
  it("rejects a declared metric that differs from its JSON source", () => {
    expect(() => validateMetric({ Total: { pct2ResTime: 42 } }, {
      name: "p95Ms", sourcePath: "Total.pct2ResTime", expectedValue: 99,
    }, "Statistics 42")).toThrow(/source mismatch/i);
  });

  it("rejects a metric whose visible page pattern is absent", () => {
    expect(() => validateMetric({ totalIssues: 17 }, {
      name: "issues", sourcePath: "totalIssues", expectedValue: 17, pagePattern: "17 issues",
    }, "No visible issue count")).toThrow(/not visible/i);
  });

  it("rejects credential and local-user text", () => {
    expect(() => assertNoForbiddenText("Authorization: Bearer sentinel")).toThrow(/sensitive/i);
    expect(() => assertNoForbiddenText("C:/Users/Researcher/repo")).toThrow(/sensitive/i);
  });
});
