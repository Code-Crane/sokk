import { app } from "./app";
import { environment } from "./config/environment";

app.listen(environment.port, () => {
  console.log(`Mukking API listening on http://localhost:${environment.port}`);
});

