import { useState } from "react";
import { canStartAdminSession } from "../lib/adminAuth";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [otpCode, setOtpCode] = useState("");
  const [message, setMessage] = useState("화이트리스트 이메일과 2단계 인증 코드가 필요합니다.");

  const submit = () => {
    setMessage(
      canStartAdminSession({ email, otpCode })
        ? "관리자 MFA 입력 형식은 준비되었습니다. 실제 권한은 서버 JWT+whitelist+aal2 검증으로만 확정됩니다."
        : "관리자 화이트리스트 또는 2단계 인증 확인에 실패했습니다."
    );
  };

  return (
    <main style={styles.main}>
      <section style={styles.panel}>
        <h1>먹킹 관리자 로그인</h1>
        <input
          onChange={(event) => setEmail(event.target.value)}
          placeholder="admin email"
          style={styles.input}
          value={email}
        />
        <input
          onChange={(event) => setOtpCode(event.target.value)}
          placeholder="2FA code"
          style={styles.input}
          value={otpCode}
        />
        <button onClick={submit} style={styles.button} type="button">
          로그인 확인
        </button>
        <p>{message}</p>
      </section>
    </main>
  );
}

const styles = {
  main: {
    background: "#f3f7f4",
    minHeight: "100vh",
    padding: 32
  },
  panel: {
    background: "#ffffff",
    border: "1px solid #d8e0e6",
    borderRadius: 8,
    display: "grid",
    gap: 12,
    maxWidth: 420,
    padding: 24
  },
  input: {
    border: "1px solid #cbd5e1",
    borderRadius: 8,
    fontSize: 16,
    padding: 12
  },
  button: {
    background: "#1f7a5c",
    border: 0,
    borderRadius: 8,
    color: "#ffffff",
    cursor: "pointer",
    fontWeight: 700,
    padding: 12
  }
} as const;
