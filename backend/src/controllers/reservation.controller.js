const pool = require('../config/db');

// Créer une réservation
const createReservation = async (req, res) => {
  if (req.user.role !== 'client') {
    return res.status(403).json({ message: 'Seuls les clients peuvent faire une réservation.' });
  }
  const {
    prestataire_id, service_id, date_intervention,
    duree_heures, adresse_intervention, description_besoin
  } = req.body;

  if (!prestataire_id || !service_id || !date_intervention || !duree_heures || !adresse_intervention) {
    return res.status(400).json({ message: 'Champs obligatoires manquants.' });
  }

  try {
    // Récupérer le tarif pour calculer le montant
    const service = await pool.query(
      'SELECT tarif_horaire FROM services WHERE id = $1',
      [service_id]
    );
    if (service.rows.length === 0) {
      return res.status(404).json({ message: 'Service non trouvé.' });
    }

    const montant_total = service.rows[0].tarif_horaire * duree_heures;

    const result = await pool.query(
      `INSERT INTO reservations
        (client_id, prestataire_id, service_id, date_intervention, duree_heures,
         adresse_intervention, description_besoin, montant_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [req.user.id, prestataire_id, service_id, date_intervention,
       duree_heures, adresse_intervention, description_besoin, montant_total]
    );

    res.status(201).json({
      message: 'Réservation créée avec succès !',
      reservation: result.rows[0]
    });
  } catch (err) {
    console.error('Erreur createReservation:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Mes réservations (client ou prestataire)
const getMesReservations = async (req, res) => {
  try {
    let query;
    const params = [req.user.id];

    if (req.user.role === 'client') {
      query = `
        SELECT r.*, 
               u.nom as prestataire_nom, u.prenom as prestataire_prenom,
               u.telephone as prestataire_tel, u.photo_url,
               c.nom as categorie_nom, c.icone,
               s.titre as service_titre
        FROM reservations r
        JOIN users u ON u.id = r.prestataire_id
        JOIN services s ON s.id = r.service_id
        JOIN categories c ON c.id = s.categorie_id
        WHERE r.client_id = $1
        ORDER BY r.created_at DESC
      `;
    } else {
      query = `
        SELECT r.*,
               u.nom as client_nom, u.prenom as client_prenom,
               u.telephone as client_tel,
               s.titre as service_titre
        FROM reservations r
        JOIN users u ON u.id = r.client_id
        JOIN services s ON s.id = r.service_id
        WHERE r.prestataire_id = $1
        ORDER BY r.created_at DESC
      `;
    }

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Mettre à jour le statut d'une réservation
const updateStatut = async (req, res) => {
  const { id } = req.params;
  const { statut } = req.body;

  const statutsValides = ['confirme', 'en_cours', 'termine', 'annule'];
  if (!statutsValides.includes(statut)) {
    return res.status(400).json({ message: 'Statut invalide.' });
  }

  try {
    const result = await pool.query(
      `UPDATE reservations SET statut = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND (client_id = $3 OR prestataire_id = $3) RETURNING *`,
      [statut, id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Réservation non trouvée.' });
    }
    res.json({ message: 'Statut mis à jour.', reservation: result.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Laisser un avis
const laisserAvis = async (req, res) => {
  const { reservation_id, note, commentaire } = req.body;
  if (!reservation_id || !note) {
    return res.status(400).json({ message: 'reservation_id et note requis.' });
  }

  try {
    // Vérifier que la réservation est terminée et appartient au client
    const resa = await pool.query(
      `SELECT * FROM reservations WHERE id = $1 AND client_id = $2 AND statut = 'termine'`,
      [reservation_id, req.user.id]
    );
    if (resa.rows.length === 0) {
      return res.status(403).json({ message: 'Impossible de laisser un avis pour cette réservation.' });
    }

    const { prestataire_id } = resa.rows[0];

    await pool.query(
      `INSERT INTO avis (reservation_id, client_id, prestataire_id, note, commentaire)
       VALUES ($1, $2, $3, $4, $5)`,
      [reservation_id, req.user.id, prestataire_id, note, commentaire]
    );

    // Mettre à jour la note moyenne du prestataire
    await pool.query(
      `UPDATE users SET
         note_moyenne = (SELECT AVG(note) FROM avis WHERE prestataire_id = $1),
         nombre_avis = (SELECT COUNT(*) FROM avis WHERE prestataire_id = $1)
       WHERE id = $1`,
      [prestataire_id]
    );

    res.status(201).json({ message: 'Avis enregistré avec succès !' });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Mettre à jour le statut de paiement
const updateStatutPaiement = async (req, res) => {
  const { id } = req.params;
  const { statut_paiement } = req.body;
  const statutsValides = ['non_paye', 'paye', 'rembourse'];
  if (!statutsValides.includes(statut_paiement)) {
    return res.status(400).json({ message: 'Statut de paiement invalide.' });
  }
  try {
    const result = await pool.query(
      `UPDATE reservations SET statut_paiement = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND (client_id = $3 OR prestataire_id = $3) RETURNING *`,
      [statut_paiement, id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Réservation non trouvée.' });
    }
    res.json({ message: 'Paiement mis à jour.', reservation: result.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

module.exports = { createReservation, getMesReservations, updateStatut, laisserAvis, updateStatutPaiement };
