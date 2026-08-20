import type {
  MockVerificationInput,
  VerificationResult,
  VerificationStatusSnapshot
} from "../../../shared/types";
import { apiRequest } from "../../services/api.client";

export function getVerificationStatus(): Promise<VerificationStatusSnapshot> {
  return apiRequest<VerificationStatusSnapshot>("/api/auth/verification/status");
}

export function startMockVerification(): Promise<VerificationResult> {
  return apiRequest<VerificationResult>("/api/auth/verification/mock/start", {
    method: "POST"
  });
}

export function completeMockVerification(
  input: MockVerificationInput
): Promise<VerificationResult> {
  return apiRequest<VerificationResult>("/api/auth/verification/mock/complete", {
    method: "POST",
    body: JSON.stringify(input)
  });
}

export function submitMockVerification(
  input: MockVerificationInput
): Promise<VerificationResult> {
  return apiRequest<VerificationResult>("/api/auth/verification/mock", {
    method: "POST",
    body: JSON.stringify(input)
  });
}
