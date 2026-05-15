const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const { authMiddleware, adminMiddleware } = require('../middleware/auth.middleware');

router.use(authMiddleware, adminMiddleware);

router.get('/stats', async (req, res) => {
  try {
    const [users, prestataires, clients, services, reservations, avis] = await Promise.all([
      pool.query('SELECT COUNT(*)::int AS n FROM users'),
      pool.query("SELECT COUNT(*)::int AS n FROM users WHERE role = 'prestataire'"),
      pool.query("SELECT COUNT(*)::int AS n FROM users WHERE role = 'client'"),
      pool.query('SELECT COUNT(*)::int AS n FROM services'),
      pool.query('SELECT COUNT(*)::int AS n FROM reservations'),
      pool.query('SELECT COUNT(*)::int AS n FROM avis')
    ]);
    res.json({
      utilisateurs: users.rows[0].n,
      prestataires: prestataires.rows[0].n,
      clients: clients.rows[0].n,
      services: services.rows[0].n,
      reservations: reservations.rows[0].n,
      avis: avis.rows[0].n
    });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
});

router.get('/utilisateurs', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, nom, prenom, telephone, role, quartier, est_actif, est_verifie, created_at
       FROM users ORDER BY created_at DESC LIMIT 100`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
});

router.patch('/utilisateurs/:id/verifier', async (req, res) => {
  const { id } = req.params;
  const { est_verifie } = req.body;
  try {
    const result = await pool.query(
      `UPDATE users SET est_verifie = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND role = 'prestataire' RETURNING id, nom, prenom, est_verifie`,
      [!!est_verifie, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Prestataire non trouvé.' });
    }
    res.json({ message: 'Statut de vérification mis à jour.', user: result.rows[0] });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
});

module.exports = router;
