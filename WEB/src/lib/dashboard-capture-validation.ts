export type MetricSpec = {
  name: string;
  expectedValue: string | number;
  sourcePath?: string;
  sourceKind?: "path" | "zap-risk-count";
  riskCode?: number;
  pagePattern?: string;
};

const forbidden = [
  /Password\s*=/i,
  /sonar\.token\s*=/i,
  /Authorization:\s*(?:Bearer|Basic)/i,
  /[A-Za-z]:[\\/]Users[\\/](?!\[USER\])[^\\/]+/i,
];

function getByPath(value: unknown, dottedPath: string): unknown {
  return dottedPath.split(".").reduce<unknown>((current, segment) => {
    if (current === null || typeof current !== "object") return undefined;
    return (current as Record<string, unknown>)[segment];
  }, value);
}

function getZapRiskCount(value: unknown, riskCode: number): number {
  const root = value as { site?: Array<{ alerts?: Array<{ riskcode?: string | number }> }> | { alerts?: Array<{ riskcode?: string | number }> } };
  const sites = Array.isArray(root.site) ? root.site : root.site ? [root.site] : [];
  return sites.flatMap((site) => site.alerts ?? []).filter((alert) => Number(alert.riskcode) === riskCode).length;
}

export function assertNoForbiddenText(text: string): void {
  if (forbidden.some((pattern) => pattern.test(text))) throw new Error("Sensitive text is visible in the dashboard capture region.");
}

export function validateMetric(sourceData: unknown, metric: MetricSpec, visibleText: string): string | number {
  const sourceValue = metric.sourceKind === "zap-risk-count"
    ? getZapRiskCount(sourceData, metric.riskCode ?? -1)
    : getByPath(sourceData, metric.sourcePath ?? "");
  if (String(sourceValue) !== String(metric.expectedValue)) {
    throw new Error(`${metric.name} source mismatch: expected ${metric.expectedValue}, got ${String(sourceValue)}`);
  }
  if (!metric.pagePattern) throw new Error(`${metric.name} does not declare a visible page pattern.`);
  if (!new RegExp(metric.pagePattern, "i").test(visibleText)) throw new Error(`${metric.name} is not visible in the captured region.`);
  return metric.expectedValue;
}
