import { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import type { CreateMatchingPostInput } from "../../shared/types";
import { PrimaryButton } from "./PrimaryButton";

interface CreatePostFormProps {
  disabled?: boolean;
  disabledReason?: string;
  isSubmitting: boolean;
  onSubmit: (input: CreateMatchingPostInput) => Promise<void>;
}

function tomorrowIso(): string {
  return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
}

export function CreatePostForm({
  disabled = false,
  disabledReason,
  isSubmitting,
  onSubmit
}: CreatePostFormProps) {
  const [restaurantName, setRestaurantName] = useState("동네 국밥집");
  const [address, setAddress] = useState("서울시 어딘가 1층");
  const [scheduledAt, setScheduledAt] = useState(tomorrowIso());
  const [maxParticipants, setMaxParticipants] = useState("1");
  const [intro, setIntro] = useState("혼자 가기 애매해서 같이 먹을 분 구해요.");

  const submit = async () => {
    await onSubmit({
      restaurantName,
      address,
      scheduledAt,
      maxParticipants: Number(maxParticipants),
      intro
    });
  };

  return (
    <View style={styles.panel}>
      <Text style={styles.heading}>이 맛집 같이 가요</Text>
      {disabledReason ? <Text style={styles.notice}>{disabledReason}</Text> : null}
      <TextInput
        onChangeText={setRestaurantName}
        placeholder="식당명"
        style={styles.input}
        value={restaurantName}
      />
      <TextInput
        onChangeText={setAddress}
        placeholder="위치"
        style={styles.input}
        value={address}
      />
      <TextInput
        autoCapitalize="none"
        onChangeText={setScheduledAt}
        placeholder="희망 시간 ISO"
        style={styles.input}
        value={scheduledAt}
      />
      <TextInput
        keyboardType="number-pad"
        onChangeText={setMaxParticipants}
        placeholder="모집 인원"
        style={styles.input}
        value={maxParticipants}
      />
      <TextInput
        multiline
        onChangeText={setIntro}
        placeholder="한줄 소개"
        style={[styles.input, styles.textArea]}
        value={intro}
      />
      <PrimaryButton disabled={disabled || isSubmitting} onPress={submit}>
        모집 글 등록
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
    gap: 10,
    padding: 16
  },
  heading: {
    color: "#172026",
    fontSize: 18,
    fontWeight: "800"
  },
  notice: {
    color: "#b45309",
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
    paddingVertical: 10
  },
  textArea: {
    minHeight: 72,
    textAlignVertical: "top"
  }
});
