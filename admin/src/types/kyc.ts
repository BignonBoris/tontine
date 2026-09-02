export type KycStatus = "unverified" | "pending_review" | "verified" | "rejected" | "expired" | "suspended";

export interface KycDocument {
  id: string;
  documentType: string;
  countryCode: string;
  documentNumber: string | null;
  status: string;
  submittedAt: string;
}

export interface KycCase {
  id: string;
  status: KycStatus;
  level: string;
  submittedAt: string | null;
  reviewedAt: string | null;
  expiresAt: string | null;
  rejectionReason: string | null;
  documents: KycDocument[];
  user?: {
    id: string;
    displayName: string;
    firstName: string | null;
    lastName: string | null;
    phoneNumber: string | null;
    birthDate?: string | null;
  } | null;
  decisions?: Array<{
    id: string;
    decision: string;
    reason: string | null;
    decidedBy: string;
    decidedAt: string;
  }>;
}
