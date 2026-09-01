import type { PropsWithChildren } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

interface ScreenShellProps extends PropsWithChildren {
  title: string;
  subtitle?: string;
}

export function ScreenShell({ title, subtitle, children }: ScreenShellProps) {
  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>{title}</Text>
        {subtitle ? <Text style={styles.subtitle}>{subtitle}</Text> : null}
      </View>
      {children}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 18,
    padding: 18,
    paddingBottom: 36
  },
  header: {
    gap: 6
  },
  title: {
    color: "#172026",
    fontSize: 28,
    fontWeight: "800"
  },
  subtitle: {
    color: "#5b6470",
    fontSize: 15,
    lineHeight: 22
  }
});

