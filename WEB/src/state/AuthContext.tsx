import { createContext, useCallback, useContext, useMemo, useState } from "react";
import { ApiClient, type CurrentUser } from "../lib/api";

const DEFAULT_API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:5296";
const TOKEN_KEY = "financial-accounting.accessToken";
const EXPIRY_KEY = "financial-accounting.accessTokenExpiresAtUtc";
const ROLES_KEY = "financial-accounting.roles";
const API_BASE_KEY = "financial-accounting.apiBaseUrl";

type AuthState = {
  apiBaseUrl: string;
  client: ApiClient;
  token: string | null;
  roles: string[];
  expiresAt: string | null;
  currentUser: CurrentUser | null;
  isAuthenticated: boolean;
  setApiBaseUrl: (baseUrl: string) => void;
  login: (username: string, password: string) => Promise<void>;
  refreshUser: () => Promise<void>;
  logout: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

function readStoredRoles(): string[] {
  const raw = localStorage.getItem(ROLES_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw) as string[];
  } catch {
    return [];
  }
}

function isExpired(expiresAt: string | null): boolean {
  return Boolean(expiresAt && Date.parse(expiresAt) <= Date.now());
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [apiBaseUrl, setApiBaseUrlState] = useState(() => localStorage.getItem(API_BASE_KEY) ?? DEFAULT_API_BASE_URL);
  const [token, setToken] = useState(() => localStorage.getItem(TOKEN_KEY));
  const [expiresAt, setExpiresAt] = useState(() => localStorage.getItem(EXPIRY_KEY));
  const [roles, setRoles] = useState<string[]>(readStoredRoles);
  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null);

  const logout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(EXPIRY_KEY);
    localStorage.removeItem(ROLES_KEY);
    setToken(null);
    setExpiresAt(null);
    setRoles([]);
    setCurrentUser(null);
  }, []);

  const client = useMemo(() => new ApiClient(apiBaseUrl, () => localStorage.getItem(TOKEN_KEY)), [apiBaseUrl]);

  const setApiBaseUrl = useCallback((baseUrl: string) => {
    const normalized = baseUrl.replace(/\/$/, "");
    localStorage.setItem(API_BASE_KEY, normalized);
    setApiBaseUrlState(normalized);
  }, []);

  const refreshUser = useCallback(async () => {
    if (!localStorage.getItem(TOKEN_KEY)) return;
    const user = await client.getCurrentUser();
    setCurrentUser(user);
    setRoles(user.roles);
    localStorage.setItem(ROLES_KEY, JSON.stringify(user.roles));
  }, [client]);

  const login = useCallback(
    async (username: string, password: string) => {
      const result = await client.login(username, password);
      localStorage.setItem(TOKEN_KEY, result.accessToken);
      localStorage.setItem(EXPIRY_KEY, result.accessTokenExpiresAtUtc);
      localStorage.setItem(ROLES_KEY, JSON.stringify(result.roles));
      setToken(result.accessToken);
      setExpiresAt(result.accessTokenExpiresAtUtc);
      setRoles(result.roles);
      const user = await new ApiClient(apiBaseUrl, () => result.accessToken).getCurrentUser();
      setCurrentUser(user);
    },
    [apiBaseUrl, client],
  );

  if (token && isExpired(expiresAt)) {
    logout();
  }

  const value = useMemo<AuthState>(
    () => ({
      apiBaseUrl,
      client,
      token,
      roles,
      expiresAt,
      currentUser,
      isAuthenticated: Boolean(token) && !isExpired(expiresAt),
      setApiBaseUrl,
      login,
      refreshUser,
      logout,
    }),
    [apiBaseUrl, client, currentUser, expiresAt, login, logout, refreshUser, roles, setApiBaseUrl, token],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }
  return context;
}
