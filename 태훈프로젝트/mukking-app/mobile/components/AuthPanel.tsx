import { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import type { LoginInput, SignupInput } from "../../shared/types";
import { PrimaryButton } from "./PrimaryButton";

interface AuthPanelProps {
  isSubmitting: boolean;
  error?: string | null;
  onLogin: (input: LoginInput) => Promise<void>;
  onSignup: (input: SignupInput) => Promise<void>;
}

export function AuthPanel({ isSubmitting, error, onLogin, onSignup }: AuthPanelProps) {
  const [mode, setMode] = useState<"signup" | "login">("signup");
  const [email, setEmail] = useState("solo@mukking.test");
  const [nickname, setNickname] = useState("혼밥탈출러");
  const [phoneNumber, setPhoneNumber] = useState("01012345678");

  const submit = async () => {
    if (mode === "signup") {
      await onSignup({ email, nickname, phoneNumber });
      return;
    }

    await onLogin({ email });
  };

  return (
    <View style={styles.panel}>
      <Text style={styles.heading}>
        {mode === "signup" ? "먹킹 시작하기" : "다시 들어오기"}
      </Text>
      <Text style={styles.description}>
        Phase 1에서는 PASS 연동 대신 목업 계정으로 인증 완료 상태를 만듭니다.
      </Text>
      <TextInput
        autoCapitalize="none"
        keyboardType="email-address"
        onChangeText={setEmail}
        placeholder="email"
        style={styles.input}
        value={email}
      />
      {mode === "signup" ? (
        <>
          <TextInput
            onChangeText={setNickname}
            placeholder="nickname"
            style={styles.input}
            value={nickname}
          />
          <TextInput
            keyboardType="phone-pad"
            onChangeText={setPhoneNumber}
            placeholder="phone number"
            style={styles.input}
            value={phoneNumber}
          />
        </>
      ) : null}
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <PrimaryButton disabled={isSubmitting} onPress={submit}>
        {mode === "signup" ? "회원가입" : "로그인"}
      </PrimaryButton>
      <PrimaryButton
        disabled={isSubmitting}
        onPress={() => setMode(mode === "signup" ? "login" : "signup")}
        variant="secondary"
      >
        {mode === "signup" ? "이미 계정이 있어요" : "새 계정 만들기"}
      </PrimaryButton>
    </View>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 12,
    padding: 16
  },
  heading: {
    color: "#172026",
    fontSize: 20,
    fontWeight: "800"
  },
  description: {
    color: "#5b6470",
    fontSize: 14,
    lineHeight: 20
  },
  input: {
    backgroundColor: "#f8fafc",
    borderColor: "#cbd5e1",
    borderRadius: 8,
    borderWidth: 1,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 11
  },
  error: {
    color: "#b42318",
    fontSize: 14
  }
});

