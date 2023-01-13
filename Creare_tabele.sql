--4
CREATE TABLE TARIFE_LIVRARE
(
cod_identificare_tarif NUMBER NOT NULL PRIMARY KEY,
tarif NUMBER NOT NULL,
judet_livrare VARCHAR2(300) NOT NULL
);

CREATE TABLE PRIME_PERFORMANTA
(
   prima_id NUMBER NOT NULL PRIMARY KEY,
   procent NUMBER  NOT NULL CHECK(procent>0),
   limita_colete_livrate NUMBER NOT NULL CHECK(limita_colete_livrate >0)
);

CREATE TABLE CODURI_GREUTATE
(
    cod_greutate NUMBER PRIMARY KEY,
    greutate_min NUMBER NOT NULL,
    greutate_max NUMBER NOT NULL, 
    supracost_procent NUMBER NOT NULL
);

CREATE TABLE ADRESE_LIVRARE
(
    adresa_id NUMBER PRIMARY KEY,
    adresa VARCHAR2(200) NOT NULL,
    cod_postal VARCHAR2(20) NOT NULL,
    oras VARCHAR2(50),  -- poate fi dedus din codul postal, deci nu e obligatoriu
    judet VARCHAR2(50) NOT NULL    		 	
);

CREATE TABLE CLIENTI
(
   client_id NUMBER NOT NULL PRIMARY KEY,
   tip VARCHAR2(20) NOT NULL CHECK(tip='juridic' OR tip='fizic'),
   sex VARCHAR2(10) CHECK(sex IS NULL OR sex='feminin' OR sex='masculin'), -- null in caz de persoana juridica(companie)
   nr_telefon VARCHAR2(20) NOT NULL,
   email VARCHAR2(50),
   iban_card VARCHAR2(150) NOT NULL
);

CREATE TABLE MASINI
(
   masina_id NUMBER NOT NULL PRIMARY KEY,
   marca VARCHAR2(50) NOT NULL,
   model VARCHAR2(50) NOT NULL,
   an_fabricatie NUMBER,
   tip_combustibil VARCHAR2(50) CHECK(tip_combustibil IN ('benzina', 'motorina', 'hibrid', 'electric')),
   ultima_verificareITP DATE
);

CREATE TABLE CURIERI
(
  curier_id NUMBER NOT NULL PRIMARY KEY,
  nume VARCHAR2(20) NOT NULL,
  prenume VARCHAR2(20) NOT NULL,
  nr_telefon VARCHAR2(10) NOT NULL,
  masina_id NUMBER, --nu e not null, poate nu i s-a atribuit masina inca
  data_preluare_masina DATE,
  salariu_brut NUMBER NOT NULL CHECK(salariu_brut>=2580),
  prima_id NUMBER, --nu e not null, poate nu are bonus
  prima_ocazionala NUMBER, -- nu e not null(EX prima Craciun, prima nunta etc.)
  data_angajare DATE NOT NULL,
  CONSTRAINT curieri_masini_fk FOREIGN KEY(masina_id) REFERENCES MASINI(MASINA_ID) ON DELETE SET NULL,
  CONSTRAINT curieri_prima_fk FOREIGN KEY(prima_id) REFERENCES PRIME_PERFORMANTA(PRIMA_ID) ON DELETE SET NULL
);

CREATE TABLE LIVRARI
(
  livrare_id NUMBER PRIMARY KEY,
  data_estimare_livrare DATE NOT NULL,
  curier_id NUMBER NOT NULL,
  CONSTRAINT livrari_courier_fk FOREIGN KEY(curier_id) REFERENCES curieri(curier_id) ON DELETE CASCADE
);

CREATE TABLE COMENZI
(
   comanda_id NUMBER PRIMARY KEY,
   client_id NUMBER NOT NULL,
   data_comanda DATE NOT NULL,
   metoda_plata VARCHAR2(50) NOT NULL CHECK(metoda_plata='card online' OR metoda_plata='card la primire' OR metoda_plata='cash la primire' OR metoda_plata='pay pal'),
   pret_colet FLOAT NOT NULL, --al pachetului, fara transport si taxe extra
   cod_greutate NUMBER NOT NULL,
   adresa_facturare VARCHAR2(100) NOT NULL,
   adresa_livrare_id NUMBER NOT NULL,
   cod_identificare_tarif NUMBER NOT NULL,
   CONSTRAINT comenzi_clienti_fk FOREIGN KEY(client_id) REFERENCES CLIENTI(client_id) ON DELETE CASCADE,
   CONSTRAINT comenzi_greutate_fk FOREIGN KEY(cod_greutate) REFERENCES CODURI_GREUTATE(cod_greutate) ON DELETE CASCADE,
   CONSTRAINT comenzi_adresa_livrare_fk FOREIGN KEY(adresa_livrare_id) REFERENCES ADRESE_LIVRARE(adresa_id) ON DELETE CASCADE,
   CONSTRAINT comenzi_tarife_livrare_fk FOREIGN KEY(cod_identificare_tarif) REFERENCES TARIFE_LIVRARE(cod_identificare_tarif)  ON DELETE CASCADE
);

CREATE TABLE PERS_FIZICE
(
   client_id NUMBER NOT NULL PRIMARY KEY,
   nume VARCHAR2(50) NOT NULL,
   prenume VARCHAR2(50) NOT NULL,
   varsta NUMBER CHECK(varsta>=16),
   CONSTRAINT clienti_pers_fizice_fk FOREIGN KEY(client_id) REFERENCES CLIENTI(client_id) ON DELETE CASCADE
);

CREATE TABLE COMPANIE
(
   client_id NUMBER NOT NULL PRIMARY KEY,
   denumire VARCHAR2(100) NOT NULL,
   pers_contact_nume VARCHAR2(20) NOT NULL,
   pers_contact_prenume VARCHAR2(20) NOT NULL,
   cod_fiscal VARCHAR2(50) NOT NULL,
   CONSTRAINT clienti_companie_fk FOREIGN KEY(client_id) REFERENCES CLIENTI(client_id) ON DELETE CASCADE
);

CREATE TABLE ISTORIC_MASINI
(
   curier_id NUMBER,
   data_preluare_masina DATE NOT NULL,
   data_predare_masina DATE NOT NULL,
   masina_id NUMBER NOT NULL,
   PRIMARY KEY(curier_id, data_preluare_masina),
   CONSTRAINT istoric_masini_masini_fk FOREIGN KEY(masina_id) REFERENCES MASINI(masina_id) ON DELETE CASCADE,
   CONSTRAINT istoric_masini_curieri_fk FOREIGN KEY(curier_id) REFERENCES CURIERI(curier_id) ON DELETE CASCADE
);

CREATE TABLE ACCIDENTE
(
   accident_id NUMBER NOT NULL PRIMARY KEY,
   curier_id NUMBER NOT NULL,
   masina_id NUMBER NOT NULL,
   data_accident DATE NOT NULL,
   cost_daune NUMBER NOT NULL,
   CONSTRAINT accidente_masini_fk FOREIGN KEY(masina_id) REFERENCES MASINI(masina_id) ON DELETE CASCADE,
   CONSTRAINT accidente_curieri_fk FOREIGN KEY(curier_id) REFERENCES CURIERI(curier_id) ON DELETE CASCADE
);

CREATE TABLE PROCESARE
(
  comanda_id NUMBER NOT NULL,
  livrare_id NUMBER NOT NULL,
  status VARCHAR2(10) CHECK(status IS NULL OR status='success' OR status='failed'),
  tarif FLOAT NOT NULL,
  nr_produse NUMBER,
  PRIMARY KEY(livrare_id, comanda_id),
  CONSTRAINT procesare_livrari_fk FOREIGN KEY(livrare_id) REFERENCES LIVRARI(livrare_id) ON DELETE CASCADE,
  CONSTRAINT procesare_comenzi_fk  FOREIGN KEY(comanda_id) REFERENCES COMENZI(comanda_id) ON DELETE CASCADE
);