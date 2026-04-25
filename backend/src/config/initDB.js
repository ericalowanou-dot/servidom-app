
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

const createTables = async () => {
  try {
    // Table users (clients et prestataires)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        nom VARCHAR(100) NOT NULL,
        prenom VARCHAR(100) NOT NULL,
        email VARCHAR(150) UNIQUE,
        telephone VARCHAR(20) UNIQUE NOT NULL,
        mot_de_passe VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL CHECK (role IN ('client', 'prestataire', 'admin')),
        photo_url VARCHAR(255),
        quartier VARCHAR(100),
        ville VARCHAR(100) DEFAULT 'Lomé',
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        est_verifie BOOLEAN DEFAULT FALSE,
        est_actif BOOLEAN DEFAULT TRUE,
        note_moyenne DECIMAL(3, 2) DEFAULT 0,
        nombre_avis INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✅ Table users créée');

    // Table categories de services
    await pool.query(`
      CREATE TABLE IF NOT EXISTS categories (
        id SERIAL PRIMARY KEY,
        nom VARCHAR(100) NOT NULL,
        description TEXT,
        icone VARCHAR(100),
        est_actif BOOLEAN DEFAULT TRUE
      );
    `);
    console.log('✅ Table categories créée');

    // Insérer les catégories ServiDom
    await pool.query(`
      INSERT INTO categories (nom, description, icone) VALUES
        ('Cuisinière', 'Préparation de repas à domicile', 'restaurant'),
        ('Ménagère', 'Nettoyage et entretien de la maison', 'cleaning_services'),
        ('Jardinier', 'Entretien des jardins et espaces verts', 'yard'),
        ('Plombier', 'Réparations et installations de plomberie', 'plumbing'),
        ('Électricien', 'Travaux électriques et installations', 'electrical_services'),
        ('Sécurité', 'Gardiennage et surveillance', 'security')
      ON CONFLICT DO NOTHING;
    `);
    console.log('✅ Catégories insérées');

    // Table services (offres des prestataires)
    await pool.query(`
      CREATE TABLE IF NOT EXISTS services (
        id SERIAL PRIMARY KEY,
        prestataire_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        categorie_id INTEGER REFERENCES categories(id),
        titre VARCHAR(200) NOT NULL,
        description TEXT,
        tarif_horaire DECIMAL(10, 2) NOT NULL,
        disponible BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✅ Table services créée');

    // Table reservations
    await pool.query(`
      CREATE TABLE IF NOT EXISTS reservations (
        id SERIAL PRIMARY KEY,
        client_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        prestataire_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        service_id INTEGER REFERENCES services(id),
        date_intervention TIMESTAMP NOT NULL,
        duree_heures DECIMAL(4, 1) NOT NULL,
        adresse_intervention TEXT NOT NULL,
        latitude DECIMAL(10, 8),
        longitude DECIMAL(11, 8),
        description_besoin TEXT,
        statut VARCHAR(30) DEFAULT 'en_attente'
          CHECK (statut IN ('en_attente', 'confirme', 'en_cours', 'termine', 'annule')),
        montant_total DECIMAL(10, 2),
        statut_paiement VARCHAR(20) DEFAULT 'non_paye'
          CHECK (statut_paiement IN ('non_paye', 'paye', 'rembourse')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✅ Table reservations créée');

    // Table avis
    await pool.query(`
      CREATE TABLE IF NOT EXISTS avis (
        id SERIAL PRIMARY KEY,
        reservation_id INTEGER REFERENCES reservations(id) ON DELETE CASCADE,
        client_id INTEGER REFERENCES users(id),
        prestataire_id INTEGER REFERENCES users(id),
        note INTEGER NOT NULL CHECK (note BETWEEN 1 AND 5),
        commentaire TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log('✅ Table avis créée');

    console.log('\n🎉 Base de données ServiDom initialisée avec succès !');
    process.exit(0);
  } catch (err) {
    console.error('❌ Erreur initialisation BDD:', err.message);
    process.exit(1);
  }
};

createTables();
