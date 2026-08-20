export interface AdminLoginInput {
  email: string;
  otpCode: string;
}

export interface AdminMfaPreparationResult {
  isWhitelistedEmail: boolean;
  hasMfaCodeShape: boolean;
  canAttemptServerLogin: boolean;
}

export function getAdminWhitelist(): string[] {
  return (process.env.NEXT_PUBLIC_ADMIN_EMAIL_WHITELIST ?? "")
    .split(",")
    .map((email) => email.trim())
    .filter(Boolean);
}

export function isWhitelistedAdmin(email: string): boolean {
  return getAdminWhitelist().includes(email);
}

export function getAdminMfaPreparationStatus(
  input: AdminLoginInput
): AdminMfaPreparationResult {
  const isWhitelistedEmail = isWhitelistedAdmin(input.email);
  const hasMfaCodeShape = input.otpCode.length >= 6;

  return {
    isWhitelistedEmail,
    hasMfaCodeShape,
    canAttemptServerLogin: isWhitelistedEmail && hasMfaCodeShape
  };
}

export function canStartAdminSession(input: AdminLoginInput): boolean {
  return getAdminMfaPreparationStatus(input).canAttemptServerLogin;
}
