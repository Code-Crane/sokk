import type { PropsWithChildren } from "react";
import { Pressable, StyleSheet, Text } from "react-native";

interface PrimaryButtonProps extends PropsWithChildren {
  onPress: () => void;
  disabled?: boolean;
  variant?: "primary" | "secondary" | "danger";
}

export function PrimaryButton({
  children,
  onPress,
  disabled = false,
  variant = "primary"
}: PrimaryButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        styles[variant],
        disabled && styles.disabled,
        pressed && !disabled && styles.pressed
      ]}
    >
      <Text style={styles.label}>{children}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: "center",
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12
  },
  primary: {
    backgroundColor: "#1f7a5c"
  },
  secondary: {
    backgroundColor: "#475569"
  },
  danger: {
    backgroundColor: "#b42318"
  },
  disabled: {
    backgroundColor: "#94a3b8"
  },
  pressed: {
    opacity: 0.8
  },
  label: {
    color: "#ffffff",
    fontSize: 15,
    fontWeight: "700"
  }
});

