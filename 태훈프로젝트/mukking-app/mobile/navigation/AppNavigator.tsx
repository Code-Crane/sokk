import { useState } from "react";
import { Pressable, SafeAreaView, StyleSheet, Text, View } from "react-native";
import { ChatRoomScreen } from "../screens/ChatRoomScreen";
import { HomeScreen } from "../screens/HomeScreen";
import { MapScreen } from "../screens/MapScreen";
import { PostDetailScreen } from "../screens/PostDetailScreen";
import { ProfileScreen } from "../screens/ProfileScreen";
import { VerificationScreen } from "../screens/VerificationScreen";

type TabId = "home" | "map" | "detail" | "chat" | "profile" | "verification";

const tabs: Array<{ id: TabId; label: string }> = [
  { id: "home", label: "홈" },
  { id: "map", label: "동네" },
  { id: "detail", label: "상세" },
  { id: "chat", label: "채팅" },
  { id: "profile", label: "프로필" },
  { id: "verification", label: "인증" }
];

export function AppNavigator() {
  const [activeTab, setActiveTab] = useState<TabId>("home");

  const renderScreen = () => {
    switch (activeTab) {
      case "map":
        return <MapScreen />;
      case "detail":
        return <PostDetailScreen />;
      case "chat":
        return <ChatRoomScreen />;
      case "profile":
        return <ProfileScreen />;
      case "verification":
        return <VerificationScreen />;
      case "home":
      default:
        return <HomeScreen />;
    }
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.content}>{renderScreen()}</View>
      <View style={styles.tabBar}>
        {tabs.map((tab) => (
          <Pressable
            key={tab.id}
            onPress={() => setActiveTab(tab.id)}
            style={[styles.tab, activeTab === tab.id ? styles.activeTab : undefined]}
          >
            <Text style={[styles.tabText, activeTab === tab.id ? styles.activeText : undefined]}>
              {tab.label}
            </Text>
          </Pressable>
        ))}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    backgroundColor: "#f3f7f4",
    flex: 1
  },
  content: {
    flex: 1
  },
  tabBar: {
    backgroundColor: "#ffffff",
    borderTopColor: "#d8e0e6",
    borderTopWidth: 1,
    flexDirection: "row",
    paddingHorizontal: 8,
    paddingVertical: 8
  },
  tab: {
    alignItems: "center",
    borderRadius: 8,
    flex: 1,
    paddingHorizontal: 4,
    paddingVertical: 10
  },
  activeTab: {
    backgroundColor: "#dff3e8"
  },
  tabText: {
    color: "#5b6470",
    fontSize: 12,
    fontWeight: "700"
  },
  activeText: {
    color: "#1f7a5c"
  }
});

