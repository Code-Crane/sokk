import { useState } from "react";
import { StyleSheet, TextInput, View } from "react-native";
import { PrimaryButton } from "./PrimaryButton";

interface MessageComposerProps {
  disabled: boolean;
  onSend: (text: string) => Promise<void>;
}

export function MessageComposer({ disabled, onSend }: MessageComposerProps) {
  const [text, setText] = useState("");

  const submit = async () => {
    if (!text.trim()) {
      return;
    }

    await onSend(text);
    setText("");
  };

  return (
    <View style={styles.row}>
      <TextInput
        editable={!disabled}
        onChangeText={setText}
        placeholder="메시지 입력"
        style={styles.input}
        value={text}
      />
      <PrimaryButton disabled={disabled} onPress={submit}>
        전송
      </PrimaryButton>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: "row",
    gap: 8
  },
  input: {
    backgroundColor: "#ffffff",
    borderColor: "#cbd5e1",
    borderRadius: 8,
    borderWidth: 1,
    flex: 1,
    fontSize: 15,
    paddingHorizontal: 12,
    paddingVertical: 10
  }
});

