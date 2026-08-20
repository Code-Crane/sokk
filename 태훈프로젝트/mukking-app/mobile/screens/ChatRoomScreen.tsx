import { StyleSheet, Text, View } from "react-native";
import { ChatRoomList } from "../components/ChatRoomList";
import { MessageComposer } from "../components/MessageComposer";
import { ScreenShell } from "../components/ScreenShell";
import { useAuth } from "../features/auth/auth.hooks";
import { useChatRooms } from "../features/chat/chat.hooks";

export function ChatRoomScreen() {
  const auth = useAuth();
  const chat = useChatRooms();

  if (!auth.user) {
    return (
      <ScreenShell title="채팅" subtitle="채팅은 로그인 후 사용할 수 있습니다.">
        <Text style={styles.empty}>먼저 홈에서 목업 계정으로 로그인해 주세요.</Text>
      </ScreenShell>
    );
  }

  if (auth.user.verificationStatus !== "verified") {
    return (
      <ScreenShell title="채팅" subtitle="채팅은 본인인증 완료 후 사용할 수 있습니다.">
        <Text style={styles.empty}>현재 인증 상태: {auth.user.verificationStatus}</Text>
      </ScreenShell>
    );
  }

  return (
    <ScreenShell
      title="채팅"
      subtitle="참가 요청이 수락되면 자동으로 열린 채팅방이 여기에 표시됩니다."
    >
      {chat.error ? <Text style={styles.error}>{chat.error}</Text> : null}
      <ChatRoomList
        activeRoomId={chat.activeRoomId}
        onOpenRoom={chat.openRoom}
        rooms={chat.rooms}
      />

      <View style={styles.messages}>
        <Text style={styles.heading}>대화</Text>
        {chat.activeMessages.length === 0 ? (
          <Text style={styles.empty}>아직 메시지가 없습니다.</Text>
        ) : (
          chat.activeMessages.map((message) => (
            <View key={message.id} style={styles.messageBubble}>
              <Text style={styles.sender}>{message.senderId}</Text>
              <Text style={styles.messageText}>{message.text}</Text>
            </View>
          ))
        )}
      </View>

      <MessageComposer
        disabled={!chat.activeRoomId}
        onSend={(text) =>
          chat.activeRoomId ? chat.sendMessage(chat.activeRoomId, text) : Promise.resolve()
        }
      />
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  messages: {
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
  messageBubble: {
    backgroundColor: "#f8fafc",
    borderRadius: 8,
    gap: 4,
    padding: 10
  },
  sender: {
    color: "#5b6470",
    fontSize: 12,
    fontWeight: "700"
  },
  messageText: {
    color: "#26323d",
    fontSize: 15
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  },
  error: {
    color: "#b42318",
    fontSize: 14
  }
});
