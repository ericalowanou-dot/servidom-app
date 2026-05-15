const fs = require('fs');
const path = require('path');
const multer = require('multer');
const pool = require('../config/db');

const serviceUploadDir = path.join(__dirname, '../../uploads/services');
fs.mkdirSync(serviceUploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, serviceUploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext || '.jpg';
    cb(null, `service-${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExt}`);
  }
});

const fileFilter = (req, file, cb) => {
  if (!file.mimetype || !file.mimetype.startsWith('image/')) {
    return cb(new Error('Le fichier doit être une image.'));
  }
  cb(null, true);
};

const uploadServiceImage = multer({
  storage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }
}).single('image');

// Toutes les catégories
const getCategories = async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM categories WHERE est_actif = TRUE ORDER BY nom'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Prestataires disponibles (avec filtre par catégorie et localisation)
const getPrestataires = async (req, res) => {
  const { categorie_id, quartier, verifie_only } = req.query;
  const onlyVerified = verifie_only === 'true' || verifie_only === '1';

  try {
    let query = `
      SELECT u.id, u.nom, u.prenom, u.photo_url, u.quartier, u.ville,
             u.note_moyenne, u.nombre_avis, u.est_verifie,
             s.id as service_id, s.titre, s.description, s.tarif_horaire, s.image_url,
             c.nom as categorie_nom, c.icone
      FROM users u
      JOIN services s ON s.prestataire_id = u.id
      JOIN categories c ON c.id = s.categorie_id
      WHERE u.role = 'prestataire'
        AND u.est_actif = TRUE
        AND s.disponible = TRUE
    `;
    const params = [];

    if (categorie_id) {
      params.push(categorie_id);
      query += ` AND s.categorie_id = $${params.length}`;
    }
    if (quartier) {
      params.push(`%${quartier}%`);
      query += ` AND u.quartier ILIKE $${params.length}`;
    }
    if (onlyVerified) {
      query += ' AND u.est_verifie = TRUE';
    }

    query += ' ORDER BY u.est_verifie DESC, u.note_moyenne DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Erreur getPrestataires:', err.message);
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Détail d'un prestataire
const getPrestataire = async (req, res) => {
  const { id } = req.params;
  try {
    const user = await pool.query(
      `SELECT id, nom, prenom, photo_url, quartier, ville, note_moyenne, nombre_avis, est_verifie, created_at
       FROM users WHERE id = $1 AND role = 'prestataire'`,
      [id]
    );
    if (user.rows.length === 0) {
      return res.status(404).json({ message: 'Prestataire non trouvé.' });
    }

    const services = await pool.query(
      `SELECT s.*, c.nom as categorie_nom, c.icone
       FROM services s JOIN categories c ON c.id = s.categorie_id
       WHERE s.prestataire_id = $1 AND s.disponible = TRUE`,
      [id]
    );

    const avis = await pool.query(
      `SELECT a.note, a.commentaire, a.created_at, u.nom, u.prenom
       FROM avis a JOIN users u ON u.id = a.client_id
       WHERE a.prestataire_id = $1 ORDER BY a.created_at DESC LIMIT 10`,
      [id]
    );

    res.json({
      prestataire: user.rows[0],
      services: services.rows,
      avis: avis.rows
    });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Créer un service (prestataire seulement)
const createService = async (req, res) => {
  if (req.user.role !== 'prestataire') {
    return res.status(403).json({ message: 'Réservé aux prestataires.' });
  }
  const { categorie_id, titre, description, tarif_horaire } = req.body;
  if (!categorie_id || !titre || !tarif_horaire) {
    return res.status(400).json({ message: 'Champs obligatoires manquants.' });
  }
  try {
    await pool.query('ALTER TABLE services ADD COLUMN IF NOT EXISTS image_url VARCHAR(255)');
    const imageUrl = req.file ? `/uploads/services/${req.file.filename}` : null;
    const result = await pool.query(
      `INSERT INTO services (prestataire_id, categorie_id, titre, description, tarif_horaire, image_url)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [req.user.id, categorie_id, titre, description, tarif_horaire, imageUrl]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Mes services (prestataire connecté)
const getMesServices = async (req, res) => {
  if (req.user.role !== 'prestataire') {
    return res.status(403).json({ message: 'Réservé aux prestataires.' });
  }
  try {
    const result = await pool.query(
      `SELECT s.*, c.nom as categorie_nom, c.icone as categorie_icone
       FROM services s
       JOIN categories c ON c.id = s.categorie_id
       WHERE s.prestataire_id = $1
       ORDER BY s.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Modifier un service
const updateService = async (req, res) => {
  if (req.user.role !== 'prestataire') {
    return res.status(403).json({ message: 'Réservé aux prestataires.' });
  }
  const { id } = req.params;
  const { categorie_id, titre, description, tarif_horaire, disponible } = req.body;
  const disponibleParsed = disponible !== undefined && disponible !== ''
    ? (disponible === true || disponible === 'true')
    : undefined;
  const tarifParsed = tarif_horaire !== undefined && tarif_horaire !== ''
    ? parseFloat(tarif_horaire)
    : undefined;
  const catId = categorie_id ? parseInt(categorie_id, 10) : undefined;
  try {
    await pool.query('ALTER TABLE services ADD COLUMN IF NOT EXISTS image_url VARCHAR(255)');
    const existing = await pool.query(
      'SELECT * FROM services WHERE id = $1 AND prestataire_id = $2',
      [id, req.user.id]
    );
    if (existing.rows.length === 0) {
      return res.status(404).json({ message: 'Service non trouvé.' });
    }
    const imageUrl = req.file ? `/uploads/services/${req.file.filename}` : existing.rows[0].image_url;
    const result = await pool.query(
      `UPDATE services SET
         categorie_id = COALESCE($1, categorie_id),
         titre = COALESCE(NULLIF($2, ''), titre),
         description = COALESCE($3, description),
         tarif_horaire = COALESCE($4, tarif_horaire),
         disponible = COALESCE($5, disponible),
         image_url = COALESCE($6, image_url)
       WHERE id = $7 AND prestataire_id = $8 RETURNING *`,
      [catId, titre, description || null, tarifParsed, disponibleParsed, imageUrl, id, req.user.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

// Supprimer un service
const deleteService = async (req, res) => {
  if (req.user.role !== 'prestataire') {
    return res.status(403).json({ message: 'Réservé aux prestataires.' });
  }
  const { id } = req.params;
  try {
    const result = await pool.query(
      'DELETE FROM services WHERE id = $1 AND prestataire_id = $2 RETURNING id',
      [id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Service non trouvé.' });
    }
    res.json({ message: 'Service supprimé.' });
  } catch (err) {
    res.status(500).json({ message: 'Erreur serveur.' });
  }
};

module.exports = {
  getCategories,
  getPrestataires,
  getPrestataire,
  createService,
  uploadServiceImage,
  getMesServices,
  updateService,
  deleteService
};
