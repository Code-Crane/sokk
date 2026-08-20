export default function UsersPage() {
  return (
    <main style={styles.main}>
      <h1>유저 관리</h1>
      <p>Phase 3에서 유저 정지, 해제, 먹킹 등급 수동 조정을 연결합니다.</p>
    </main>
  );
}

const styles = {
  main: {
    background: "#f3f7f4",
    minHeight: "100vh",
    padding: 32
  }
} as const;

