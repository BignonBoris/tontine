import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";
import type { KycCase, KycStatus } from "@/types/kyc";

export const kycService = {
  list(status?: KycStatus) {
    return unwrapEnvelope<KycCase[]>(apiClient.get("/admin/kyc", { params: status ? { status } : undefined }));
  },
  get(caseId: string) {
    return unwrapEnvelope<KycCase>(apiClient.get(`/admin/kyc/${caseId}`));
  },
  review(caseId: string, decision: "verified" | "rejected" | "suspended", reason?: string) {
    return unwrapEnvelope<KycCase>(apiClient.post(`/admin/kyc/${caseId}/review`, { decision, reason }));
  },
  async documentUrl(documentId: string) {
    const response = await apiClient.get(`/admin/kyc/documents/${documentId}`, { responseType: "blob" });
    return URL.createObjectURL(response.data as Blob);
  },
};
