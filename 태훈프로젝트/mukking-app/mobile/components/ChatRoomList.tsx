import { Pressable, StyleSheet, Text, View } from "react-native";
import type { ChatRoom } from "../../shared/types";

interface ChatRoomListProps {
  activeRoomId: string | null;
  rooms: ChatRoom[];
  onOpenRoom: (roomId: string) => Promise<void>;
}

export function ChatRoomList({ activeRoomId, rooms, onOpenRoom }: ChatRoomListProps) {
  if (rooms.length === 0) {
    return <Text style={styles.empty}>수락된 매칭이 생기면 채팅방이 열립니다.</Text>;
  }

  return (
    <View style={styles.list}>
      {rooms.map((room) => (
        <Pressable
          key={room.id}
          onPress={() => onOpenRoom(room.id)}
          style={[
            styles.room,
            activeRoomId === room.id ? styles.activeRoom : undefined
          ]}
        >
          <Text style={styles.title}>{room.title}</Text>
          <Text style={styles.meta}>{room.participantIds.length}명 참여</Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  list: {
    gap: 10
  },
  room: {
    backgroundColor: "#ffffff",
    borderColor: "#d8e0e6",
    borderRadius: 8,
    borderWidth: 1,
    gap: 4,
    padding: 12
  },
  activeRoom: {
    borderColor: "#1f7a5c",
    borderWidth: 2
  },
  title: {
    color: "#172026",
    fontSize: 16,
    fontWeight: "800"
  },
  meta: {
    color: "#5b6470",
    fontSize: 13
  },
  empty: {
    color: "#5b6470",
    fontSize: 15
  }
});

