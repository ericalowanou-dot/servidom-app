const pool = require('../config/db');

const ensureMessagesTable = async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id SERIAL PRIMARY KEY,
      reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
      sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      contenu TEXT NOT NULL,
      lu BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_messages_reservation ON messages(reservation_id, created_at);
  `);
};

const assertReservationAccess = async (reservationId, userId) => {
  const resa = await pool.query(
    `SELECT id, client_id, prestataire_id, statut FROM reservations WHERE id = $1`,
    [reservationId]
  );
  if (resa.rows.length === 0) return { error: { status: 404, message: 'Réservation non trouvée.' } };
  const row = resa.rows[0];
  if (row.client_id !== userId && row.prestataire_id !== userId) {
    return { error: { status: 403, message: 'Accès refusé à cette conversation.' } };
  }
  if (row.statut === 'annule') {
    return { error: { status: 403, message: 'Conversation indisponible (réservation annulée).' } };
  }
  return { reservation: row };
};

// Liste des conversations (réservations avec dernier message)
const getMesConversations = async (req, res) => {
  try {
    await ensureMessagesTable();
    const userId = req.user.id;
    const isClient = req.user.role === 'client';

    const query = isClient
      ? `
        SELECT r.id AS reservation_id, r.statut, r.date_intervention,
               s.titre AS service_titre,
               u.nom AS autre_nom, u.prenom AS autre_prenom,
               m.contenu AS dernier_message, m.created_at AS dernier_message_at,
               (SELECT COUNT(*)::int FROM messages msg
                WHERE msg.reservation_id = r.id AND msg.sender_id != $1 AND msg.lu = FALSE) AS non_lus
        FROM reservations r
        JOIN users u ON u.id = r.prestataire_id
        JOIN services s ON s.id = r.service_id
        LEFT JOIN LATERAL (
          SELECT contenu, created_at FROM messages
          WHERE reservation_id = r.id ORDER BY created_at DESC LIMIT 1
        ) m ON TRUE
        WHERE r.client_id = $1 AND r.statut != 'annule'
        ORDER BY COALESCE(m.created_at, r.created_at) DESC
      `
      : `
        SELECT r.id AS reservation_id, r.statut, r.date_intervention,
               s.titre AS service_titre,
               u.nom AS autre_nom, u.prenom AS autre_prenom,
               m.contenu AS dernier_message, m.created_at AS dernier_message_at,
               (SELECT COUNT(*)::int FROM messages msg
                WHERE msg.reservation_id = r.id AND msg.sender_id != $1 AND msg.lu = FALSE) AS non_lus
        FROM reservations r
        JOIN users u ON u.id = r.client_id
        JOIN services s ON s.id = r.service_id
        LEFT JOIN LATERAL (
          SELECT contenu, created_at FROM messages
          WHERE reservation_id = r.id ORDER BY created_at DESC LIMIT 1
        ) m ON TRUE
        WHERE r.prestataire_id = $1 AND r.statut != 'annule'
        ORDER BY COALESCE(m.created_at, r.created_at) DESC
      `;

    const result = await pool.query(query, [userId]);
    res.json(result.rows);
  } catch (err) {
    console.error('Erreur getMesConversations:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Messages d'une réservation
const getMessages = async (req, res) => {
  const { reservationId } = req.params;
  try {
    await ensureMessagesTable();
    const access = await assertReservationAccess(parseInt(reservationId, 10), req.user.id);
    if (access.error) {
      return res.status(access.error.status).json({ message: access.error.message });
    }

    const result = await pool.query(
      `SELECT m.*, u.nom AS sender_nom, u.prenom AS sender_prenom
       FROM messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.reservation_id = $1
       ORDER BY m.created_at ASC`,
      [reservationId]
    );

    await pool.query(
      `UPDATE messages SET lu = TRUE
       WHERE reservation_id = $1 AND sender_id != $2 AND lu = FALSE`,
      [reservationId, req.user.id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error('Erreur getMessages:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Envoyer un message
const sendMessage = async (req, res) => {
  const { reservation_id, contenu } = req.body;
  if (!reservation_id || !contenu || !String(contenu).trim()) {
    return res.status(400).json({ message: 'reservation_id et contenu requis.' });
  }
  const texte = String(contenu).trim().slice(0, 2000);

  try {
    await ensureMessagesTable();
    const access = await assertReservationAccess(parseInt(reservation_id, 10), req.user.id);
    if (access.error) {
      return res.status(access.error.status).json({ message: access.error.message });
    }

    const result = await pool.query(
      `INSERT INTO messages (reservation_id, sender_id, contenu)
       VALUES ($1, $2, $3) RETURNING *`,
      [reservation_id, req.user.id, texte]
    );

    const msg = result.rows[0];
    const sender = await pool.query(
      'SELECT nom, prenom FROM users WHERE id = $1',
      [req.user.id]
    );

    res.status(201).json({
      message: 'Message envoyé.',
      data: { ...msg, sender_nom: sender.rows[0]?.nom, sender_prenom: sender.rows[0]?.prenom }
    });
  } catch (err) {
    console.error('Erreur sendMessage:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

module.exports = { getMesConversations, getMessages, sendMessage };
