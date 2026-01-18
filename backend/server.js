require("dotenv").config();
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const mysql = require("mysql2/promise");
const cors = require("cors");
const bodyParser = require("body-parser");

// CONFIGURAZIONE
const PORT = process.env.PORT || 4600;
const app = express();
const server = http.createServer(app);

// SETUP SOCKET.IO (Real-time)
const io = new Server(server, {
  cors: {
    origin: "*", // In produzione restringi questo!
    methods: ["GET", "POST"],
  },
});

// MIDDLEWARE
app.use(cors());
app.use(bodyParser.json());

// CONNESSIONE DB (Modifica con i tuoi dati NAS)
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// --- API ROUTES ---

// 1. Ottieni tutte le stanze con i loro dispositivi
app.get("/api/rooms", async (req, res) => {
  try {
    const [rooms] = await pool.query(
      "SELECT * FROM rooms ORDER BY sort_order ASC"
    );

    // Per ogni stanza, prendiamo i dispositivi
    // (In un progetto gigante si farebbe una JOIN, ma così è più leggibile per ora)
    for (let room of rooms) {
      const [devices] = await pool.query(
        "SELECT * FROM devices WHERE room_id = ?",
        [room.id]
      );
      room.devices = devices;
    }

    res.json(rooms);
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore server");
  }
});

// 2. Aggiungi un nuovo dispositivo mappato
app.post("/api/devices", async (req, res) => {
  const { room_id, ha_entity_id, friendly_name, device_type } = req.body;

  try {
    const [result] = await pool.query(
      "INSERT INTO devices (room_id, ha_entity_id, friendly_name, device_type, grid_w, grid_h) VALUES (?, ?, ?, ?, 1, 1)",
      [room_id, ha_entity_id, friendly_name, device_type]
    );

    // Restituiamo l'oggetto completo con i default, così il frontend è felice
    const newDevice = {
      id: result.insertId,
      ...req.body,
      position_x: 0.5,
      position_y: 0.5,
      grid_w: 1, // Default
      grid_h: 1, // Default
      grid_index: 0,
    };

    io.emit("device_added", newDevice);
    res.json(newDevice);
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore salvataggio dispositivo");
  }
});

// 3. Aggiorna posizione (Drag & Drop)
app.post("/api/devices/:id/position", async (req, res) => {
  const { id } = req.params;
  const { x, y } = req.body;

  try {
    await pool.query(
      "UPDATE devices SET position_x = ?, position_y = ? WHERE id = ?",
      [x, y, id]
    );

    // LA MAGIA: Notifica in tempo reale a tutti gli altri client connessi via Socket.io
    io.emit("device_moved", { id: parseInt(id), x, y });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore aggiornamento posizione");
  }
});

// 3b. Ridimensiona Widget (Bento Grid)
app.post("/api/devices/:id/resize", async (req, res) => {
  const { id } = req.params;
  const { w, h } = req.body;

  try {
    await pool.query("UPDATE devices SET grid_w = ?, grid_h = ? WHERE id = ?", [
      w,
      h,
      id,
    ]);

    // Notifica tutti i client del cambiamento
    // Usiamo un evento generico 'device_updated' che porta solo i campi cambiati
    io.emit("device_updated", { id: parseInt(id), grid_w: w, grid_h: h });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore ridimensionamento");
  }
});

// AGGIORNA POSIZIONE GRIGLIA (Free Drag)
app.post('/api/devices/:id/grid_position', async (req, res) => {
  const { id } = req.params;
  const { x, y } = req.body; // grid_x, grid_y
  
  try {
    await pool.query('UPDATE devices SET grid_x = ?, grid_y = ? WHERE id = ?', [x, y, id]);
    
    // Notifica tutti
    io.emit('device_updated', { id: parseInt(id), grid_x: x, grid_y: y });
    
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send('Errore spostamento griglia');
  }
});

// 4. Elimina un dispositivo
app.delete("/api/devices/:id", async (req, res) => {
  const { id } = req.params;

  try {
    // Cancelliamo dal DB
    await pool.query("DELETE FROM devices WHERE id = ?", [id]);

    // Notifichiamo gli altri client che il dispositivo è sparito
    io.emit("device_deleted", { id: parseInt(id) });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore eliminazione dispositivo");
  }
});

// 5. Crea una nuova stanza
app.post("/api/rooms", async (req, res) => {
  const { name, image_asset } = req.body;

  // Calcoliamo l'ordine (mettiamola per ultima)
  try {
    const [rows] = await pool.query(
      "SELECT MAX(sort_order) as maxOrder FROM rooms"
    );
    const nextOrder = (rows[0].maxOrder || 0) + 1;

    const [result] = await pool.query(
      "INSERT INTO rooms (name, image_asset, sort_order) VALUES (?, ?, ?)",
      [name, image_asset, nextOrder]
    );

    const newRoom = {
      id: result.insertId,
      name,
      image_asset,
      devices: [],
    };

    // Notifica socket
    io.emit("room_created", newRoom);

    res.json(newRoom);
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore creazione stanza");
  }
});

// 6. Elimina una stanza
app.delete("/api/rooms/:id", async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query("DELETE FROM rooms WHERE id = ?", [id]);
    io.emit("room_deleted", { id: parseInt(id) });
    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore eliminazione stanza");
  }
});

app.post("/api/devices/swap", async (req, res) => {
  const { deviceA_id, indexA, deviceB_id, indexB } = req.body;

  try {
    // Scambiamo gli indici nel DB
    await pool.query("UPDATE devices SET grid_index = ? WHERE id = ?", [
      indexB,
      deviceA_id,
    ]);
    await pool.query("UPDATE devices SET grid_index = ? WHERE id = ?", [
      indexA,
      deviceB_id,
    ]);

    // Notifichiamo il mondo
    io.emit("devices_reordered", {
      swaps: [
        { id: deviceA_id, grid_index: indexB },
        { id: deviceB_id, grid_index: indexA },
      ],
    });

    res.json({ success: true });
  } catch (err) {
    console.error(err);
    res.status(500).send("Errore swap");
  }
});

// --- SOCKET.IO EVENTS ---
io.on("connection", (socket) => {
  console.log("Un client si è connesso:", socket.id);

  socket.on("disconnect", () => {
    console.log("Client disconnesso");
  });
});

// START
server.listen(PORT, () => {
  console.log(`🚀 Server Backend attivo sulla porta ${PORT}`);
});
