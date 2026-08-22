export function createSupabaseRepositoryNotReadyError(repositoryName: string): Error {
  return Object.assign(
    new Error(
      `${repositoryName} Supabase repository requires the Phase 3 database migration before use.`
    ),
    { statusCode: 501 }
  );
}
