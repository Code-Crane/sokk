import type { VerificationClaim } from "../../../shared/types";
import { getSupabaseServiceRoleClient } from "../../config/supabase";
import { createEntityId } from "../../models/id";
import type { VerificationRepository } from "../interfaces/verification.repository";
import { throwSupabaseError } from "./helpers";
type ClaimRow={user_id:string;provider:VerificationClaim["provider"];status:VerificationClaim["status"];requested_at?:string|null;verified_at?:string|null};
const toClaim=(row:ClaimRow):VerificationClaim=>({userId:row.user_id,provider:row.provider,status:row.status,requestedAt:row.requested_at??undefined,verifiedAt:row.verified_at??undefined});
export const supabaseVerificationRepository:VerificationRepository={
  async findClaimByUserId(id){const{data,error}=await getSupabaseServiceRoleClient().from("verification_claims").select("*").eq("user_id",id).maybeSingle<ClaimRow>();if(error)throwSupabaseError(error);return data?toClaim(data):null;},
  async upsertClaim(input){const{data,error}=await getSupabaseServiceRoleClient().from("verification_claims").upsert({user_id:input.userId,provider:input.provider,status:input.status,requested_at:input.requestedAt,verified_at:input.verifiedAt,provider_transaction_id:input.providerTransactionId,metadata:input.metadata??{}},{onConflict:"user_id"}).select("*").single<ClaimRow>();if(error)throwSupabaseError(error);return toClaim(data as ClaimRow);},
  async listFailureLogsForAdmin(filter={}){let q=getSupabaseServiceRoleClient().from("verification_failure_logs").select("*").order("created_at",{ascending:false});if(filter.userId)q=q.eq("user_id",filter.userId);if(filter.provider)q=q.eq("provider",filter.provider);if(filter.reasonCode)q=q.eq("reason_code",filter.reasonCode);const{data,error}=await q;if(error)throwSupabaseError(error);return(data??[]).map((r:any)=>({id:r.id,userId:r.user_id??undefined,provider:r.provider,reasonCode:r.reason_code,message:r.message??undefined,createdAt:r.created_at}));},
  async createFailureLog(input){const{data,error}=await getSupabaseServiceRoleClient().from("verification_failure_logs").insert({id:createEntityId("vfail"),user_id:input.userId,provider:input.provider,reason_code:input.reasonCode,message:input.message,request_payload_hash:input.requestPayloadHash,ip_hash:input.ipHash,user_agent_hash:input.userAgentHash,metadata:input.metadata??{}}).select("*").single();if(error)throwSupabaseError(error);const r=data as any;return{id:r.id,userId:r.user_id??undefined,provider:r.provider,reasonCode:r.reason_code,message:r.message??undefined,createdAt:r.created_at};}
};
