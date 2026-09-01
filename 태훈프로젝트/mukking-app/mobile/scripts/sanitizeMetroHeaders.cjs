const http = require("http");

const originalSetHeader = http.ServerResponse.prototype.setHeader;

http.ServerResponse.prototype.setHeader = function setHeader(name, value) {
  if (
    typeof name === "string" &&
    name.toLowerCase() === "x-react-native-project-root" &&
    typeof value === "string"
  ) {
    return originalSetHeader.call(this, name, encodeURI(value));
  }

  return originalSetHeader.call(this, name, value);
};

