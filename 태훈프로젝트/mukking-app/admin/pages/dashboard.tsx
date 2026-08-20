export default function DashboardPage() {
  return (
    <main style={styles.main}>
      <h1>운영 대시보드</h1>
      <p>Phase 3에서 통계, 신고 처리, 제재 현황을 연결합니다.</p>
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

