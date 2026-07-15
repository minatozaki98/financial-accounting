import {
  Activity,
  BarChart3,
  BookOpenCheck,
  FileText,
  Gauge,
  Landmark,
  ShieldCheck,
  Users,
} from "lucide-react";
import type { ComponentType } from "react";

export type Role = "Admin" | "FinanceManager" | "User" | "Auditor";

export type NavItem = {
  path: string;
  label: string;
  roles: Role[];
  icon: ComponentType<{ size?: number }>;
};

export const navigation: NavItem[] = [
  { path: "/dashboard", label: "Dashboard", roles: ["Admin", "FinanceManager", "User", "Auditor"], icon: Gauge },
  { path: "/accounts", label: "Accounts", roles: ["Admin", "FinanceManager", "User", "Auditor"], icon: Landmark },
  { path: "/journal-entries", label: "Journal Entries", roles: ["Admin", "FinanceManager", "User"], icon: FileText },
  { path: "/periods", label: "Periods", roles: ["Admin", "FinanceManager", "User", "Auditor"], icon: BookOpenCheck },
  { path: "/reports", label: "Reports", roles: ["Admin", "FinanceManager", "Auditor"], icon: BarChart3 },
  { path: "/audit-logs", label: "Audit Logs", roles: ["Admin", "Auditor"], icon: Activity },
  { path: "/users", label: "Users", roles: ["Admin"], icon: Users },
  { path: "/research-evidence", label: "Research Evidence", roles: ["Admin", "FinanceManager", "User", "Auditor"], icon: ShieldCheck },
];

export function hasAnyRole(userRoles: string[], allowedRoles: Role[]): boolean {
  return allowedRoles.some((role) => userRoles.includes(role));
}

export function getAllowedNavigation(userRoles: string[]): NavItem[] {
  return navigation.filter((item) => hasAnyRole(userRoles, item.roles));
}

export function canAccessRoute(userRoles: string[], routePath: string): boolean {
  const navItem = navigation.find((item) => item.path === routePath);
  return navItem ? hasAnyRole(userRoles, navItem.roles) : true;
}

export function canMutate(userRoles: string[], area: "accounts" | "journals" | "periods" | "users"): boolean {
  if (area === "users" || area === "accounts") {
    return userRoles.includes("Admin");
  }

  if (area === "periods") {
    return userRoles.includes("Admin") || userRoles.includes("FinanceManager");
  }

  return userRoles.includes("Admin") || userRoles.includes("FinanceManager") || userRoles.includes("User");
}
