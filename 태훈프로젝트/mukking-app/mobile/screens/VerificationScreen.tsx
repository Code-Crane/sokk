import { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import { PrimaryButton } from "../components/PrimaryButton";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import {
  completeMockVerification,
  startMockVerification
} from "../features/verification/verification.service";

export function VerificationScreen() {
  const auth = useAuth();
  const [legalName, setLegalName] = useState("홍길동");
  const [birthDate, setBirthDate] = useState("1990-01-01");
  const [gender, setGender] = useState<"male" | "female" | "other">("other");
  const [phoneNumber, setPhoneNumber] = useState("01012345678");
  const [result, setResult] = useState<string | null>(null);

  const start = async () => {
    const verification = await startMockVerification();

    await auth.refreshMe();
    setResult(`본인인증 상태: ${verification.status}`);
  };

  const submit = async () => {
    const verification = await completeMockVerification({
      legalName,
      birthDate,
      gender,
      phoneNumber
    });

    await auth.refreshMe();
    setResult(`목업 본인인증 상태: ${verification.status}`);
  };

  if (!auth.user) {
    return (
      <ScreenShell title="본인인증" subtitle="로그인 후 본인인증을 진행할 수 있습니다.">
        <Text style={styles.empty}>홈에서 먼저 로그인해 주세요.</Text>
      </ScreenShell>
    );
  }

  return (
    <ScreenShell
      title="본인인증"
      subtitle="실제 PASS 연동 전까지 동일한 인터페이스를 쓰는 목업 흐름입니다."
    >
      <View style={styles.panel}>
        <Text style={styles.status}>현재 상태: {auth.user.verificationStatus}</Text>
        <PrimaryButton onPress={start} variant="secondary">
          인증 요청 시작
        </PrimaryButton>
        <TextInput
          onChangeText={setLegalName}
          placeholder="이름"
          style={styles.input}
          value={legalName}
        />
        <TextInput
          onChangeText={setBirthDate}
          placeholder="생년월일 YYYY-MM-DD"
          style={styles.input}
          value={birthDate}
        />
        <TextInput
          onChangeText={(value) =>
            setGender(value === "male" || value === "female" ? value : "other")
          }
          placeholder="gender"
          style={styles.input}
          value={gender}
        />
        <TextInput
          keyboardType="phone-pad"
          onChangeText={setPhoneNumber}
          placeholder="휴대폰 번호"
          style={styles.input}
          value={phoneNumber}
        />
        <PrimaryButton onPress={submit}>목업 인증 완료</PrimaryButton>
        {result ? <Text style={styles.result}>{result}</Text> : null}
      </View>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  panel: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 10,
    padding: 16
  },
  input: {
    backgroundColor: "#f8fafc",
    borderColor: "#cbd5e1",
    borderRadius: 8,
    borderWidth: 1,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 10
  },
  result: {
    color: "#1f7a5c",
    fontSize: 14,
    fontWeight: "700"
  },
  status: {
    color: "#26323d",
    fontSize: 15,
    fontWeight: "800"
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  }
});
