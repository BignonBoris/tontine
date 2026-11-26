import { apiClient, unwrapEnvelope } from "@/services/http/apiClient";

export type CommunityNetwork = "facebook" | "whatsapp" | "tiktok" | "instagram" | "linkedin";
export type CommunityLanguage = "fr" | "fon";
export type CommunityStatus = "draft" | "approved" | "published" | "archived";
export type CommunityKind = "post" | "reply";

export interface CommunityOptions {
  networks: { key: CommunityNetwork; label: string }[];
  languages: { key: CommunityLanguage; label: string }[];
  statuses: CommunityStatus[];
  maxPostsPerGeneration: number;
  aiConfigured: boolean;
  model: string;
}

export interface CommunityPost {
  id: string;
  reference: string;
  kind: CommunityKind;
  network: CommunityNetwork;
  networkLabel: string;
  language: CommunityLanguage;
  languageLabel: string;
  topic: string | null;
  title: string | null;
  content: string;
  hashtags: string[];
  visualIdea: string | null;
  callToAction: string | null;
  sourceText: string | null;
  category: string | null;
  sentiment: string | null;
  needsSupport: boolean;
  supportReason: string | null;
  status: CommunityStatus;
  aiModel: string | null;
  createdBy: string | null;
  approvedBy: string | null;
  approvedAt: string | null;
  publishedAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface BrandProfile {
  brandName: string;
  description: string;
  audience: string;
  tone: string;
  keyFacts: string[];
  forbiddenClaims: string[];
  supportContact: string;
  defaultHashtags: string[];
  isDefault?: boolean;
}

export interface GeneratePayload {
  networks: CommunityNetwork[];
  languages: CommunityLanguage[];
  topic: string;
  goal?: string;
  count: number;
}

export interface ReplyPayload {
  network: CommunityNetwork;
  comment: string;
  postContext?: string;
}

export interface PostFilters {
  status?: CommunityStatus | "";
  kind?: CommunityKind | "";
  network?: CommunityNetwork | "";
  needsSupport?: boolean;
  page?: number;
  limit?: number;
}

export interface PostPage {
  items: CommunityPost[];
  pagination: { page: number; limit: number; total: number; pages: number };
}

export type PostPatch = Partial<
  Pick<CommunityPost, "content" | "title" | "hashtags" | "visualIdea" | "callToAction" | "status">
>;

// La redaction par l'IA peut prendre jusqu'a une minute ou deux.
const AI_TIMEOUT_MS = 180000;

export const communityService = {
  options() {
    return unwrapEnvelope<CommunityOptions>(apiClient.get("/admin/community/options"));
  },

  getBrandProfile() {
    return unwrapEnvelope<BrandProfile>(apiClient.get("/admin/community/brand-profile"));
  },

  updateBrandProfile(payload: BrandProfile) {
    return unwrapEnvelope<BrandProfile>(apiClient.put("/admin/community/brand-profile", payload));
  },

  generate(payload: GeneratePayload) {
    return unwrapEnvelope<CommunityPost[]>(
      apiClient.post("/admin/community/generate", payload, { timeout: AI_TIMEOUT_MS })
    );
  },

  suggestReply(payload: ReplyPayload) {
    return unwrapEnvelope<CommunityPost>(
      apiClient.post("/admin/community/replies", payload, { timeout: AI_TIMEOUT_MS })
    );
  },

  list(filters: PostFilters = {}) {
    const params: Record<string, string | number> = {};
    if (filters.status) params.status = filters.status;
    if (filters.kind) params.kind = filters.kind;
    if (filters.network) params.network = filters.network;
    if (filters.needsSupport) params.needsSupport = "true";
    params.page = filters.page || 1;
    params.limit = filters.limit || 20;
    return unwrapEnvelope<PostPage>(apiClient.get("/admin/community/posts", { params }));
  },

  update(id: string, patch: PostPatch) {
    return unwrapEnvelope<CommunityPost>(apiClient.patch(`/admin/community/posts/${id}`, patch));
  },
};
