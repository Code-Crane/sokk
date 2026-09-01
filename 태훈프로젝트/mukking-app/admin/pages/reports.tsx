export default function ReportsPage() {
  return (
    <main style={styles.main}>
      <h1>신고 처리</h1>
      <p>Phase 3에서 신고 목록, 검토 상태, 제재 액션을 구현합니다.</p>
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

