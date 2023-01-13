--6
--Pentru fiecare jude? în care s-a plasat o comandã, afi?a?i numãrul de comenzi plasate, numãrul de ora?e în care au fost plasate acele comenzi(pot fi mai multe comenzi plasate în acela?i ora?) ?i numele ora?elor. 

CREATE OR REPLACE PROCEDURE ex_colectii IS
  TYPE t_judete IS TABLE of adrese_livrare.judet%type INDEX BY PLS_INTEGER; --index-by-table
   v_judete t_judete;
   TYPE t_nr_comenzi IS TABLE OF NUMBER INDEX BY PLS_INTEGER; --index-by-table
   v_nr_comenzi t_nr_comenzi;
  TYPE t_orase IS TABLE OF ADRESE_LIVRARE.oras%TYPE; --nested table
  TYPE t_total_orase IS TABLE OF t_orase; --nested table
  v_orase t_total_orase:=t_total_orase();
   nr_judete NUMBER;
  nr_orase NUMBER;
BEGIN
  SELECT DISTINCT ad.judet, COUNT(*)
  BULK COLLECT INTO v_judete, v_nr_comenzi
  FROM comenzi c JOIN ADRESE_LIVRARE ad ON c.adresa_livrare_id=ad.ADRESA_id
  GROUP BY ad.judet;

  nr_judete:=v_judete.COUNT;

  FOR i IN 1..nr_judete LOOP -- pentru fiecare judet
      v_orase.EXTEND;

      SELECT DISTINCT ad.oras
      BULK COLLECT INTO v_orase(i)
      FROM comenzi c JOIN ADRESE_LIVRARE ad ON c.adresa_livrare_id=ad.adresa_id
      WHERE ad.judet=v_judete(i);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Detalii comenzi pe jude?e: ');


  FOR i IN 1..nr_judete LOOP -- pentru fiecare judet
      DBMS_OUTPUT.PUT(v_judete(i) || ' are ' || v_nr_comenzi(i));
      IF v_nr_comenzi(i)=1 THEN
          DBMS_OUTPUT.PUT(' comanda in ');
      ELSE
          DBMS_OUTPUT.PUT(' comenzi in ');
      END IF;

        DBMS_OUTPUT.PUT(v_orase(i).COUNT);
        IF v_orase(i).COUNT=1 THEN
            DBMS_OUTPUT.PUT(' oras(');
        ELSE
            DBMS_OUTPUT.PUT(' orase(');
        END IF;

      nr_orase:=v_orase(i).COUNT;
      FOR j IN 1..nr_orase-1 LOOP
          DBMS_OUTPUT.PUT( v_orase(i)(j)|| ', ');
      END LOOP;
      DBMS_OUTPUT.PUT( v_orase(i)(nr_orase)|| ').');

      DBMS_OUTPUT.NEW_LINE;
END LOOP;
END;

BEGIN
  ex_colectii();
END;

--7
--Compania dore?te sa realizeze o statistica cu top 3 cele mai grave accidente(conform costurilor daunelor) - data accidentului, ?oferul responsabil ?i daunele materiale
--Ulterior, afi?a?i ma?inile curierilor care au fost implicate în accidente intr-un anumit an introdus de la tastatura(id, marcã, model), împreuna cu luna accidentului ?i date despre ?ofer( id, nume, prenume curier), specificand dacã este masina curentã sau nu.


CREATE OR REPLACE PROCEDURE ex_cursoare IS

an number(4) := &p_an;
-- cursor parametrizat
CURSOR c1_ex_cursoare(an NUMBER) IS
          SELECT c.curier_id curier_id, c.prenume prenume, c.nume nume, a.data_accident data_accident, a.cost_daune cost_daune, m.masina_id masina_id,
                 m.marca marca, m.model model, c.data_angajare data_angajare, istm.data_preluare_masina data_preluare_masina, istm.data_predare_masina, c.data_preluare_masina data_preluare_masina2
          FROM curieri c JOIN accidente a ON c.curier_id=a.curier_id
                         JOIN masini m ON a.masina_id=m.masina_id
                         LEFT JOIN istoric_masini istm ON (a.masina_id=istm.masina_id AND a.curier_id=istm.curier_id
                                       AND a.data_accident<=istm.DATA_PREDARE_MASINA AND a.DATA_ACCIDENT>=istm.DATA_PRELUARE_MASINA )
           WHERE EXTRACT(YEAR FROM a.data_accident) = an;
           
curenta VARCHAR2(50);
top number(1) := 0;


BEGIN
DBMS_OUTPUT.PUT_LINE('Top 3 accidente 2022 conform pagubelor');
--ciclu cursor cu subcereri
FOR i IN (SELECT c.curier_id id, c.prenume p, c.nume n, a.data_accident da, a.cost_daune cd, c.salariu_brut sb
        FROM curieri c JOIN accidente a ON c.curier_id=a.curier_id
        ORDER BY a.cost_daune DESC)
    LOOP
        DBMS_OUTPUT.PUT_LINE('Data accident: ' || i.da || '; Sofer responsabil:' || i.id || '; Daune materiale:' || i.cd);
        top := top+1;
        EXIT WHEN top = 3;
    END LOOP;

DBMS_OUTPUT.PUT_LINE('Accidente inregistrate in anul ' || an);
FOR i IN c1_ex_cursoare(an) LOOP --ciclu cursor

   IF i.data_predare_masina < i.data_accident THEN
       curenta:='masina curenta a curierului ';
   ELSE
       curenta:='masina anterioara a curierului ';
   END IF;
   DBMS_OUTPUT.PUT_LINE('Ma?ina cu numarul de identificare(id) ' || i.masina_id || ' (' || i.marca || ' ' || i.model || '),' || curenta || i.nume || ' ' || i.prenume || ', avand id-ul ' || i.curier_id || ', a fost implicata intr-un accident in luna ' || extract(month from i.data_accident) || '.');
END LOOP;

END;
/


BEGIN
   ex_cursoare();
END;

--8
--Determinati numarul de comenzi intregi livrate de un anume curier al carui id este dat. O comanda se considera intreaga daca, indiferent daca a fost procesata in mai multe colete spre livrare, toate au primit statusul 'success'.
--Pentru cazul in care curierul respectiv nu are deloc comenzi intregi repartizate pentru a fi livrate, sa se afiseze un mesaj corespunzator.

CREATE OR REPLACE FUNCTION ex_functie(curier curieri.curier_id%TYPE) RETURN NUMBER IS

CURSOR livrari_total(c_id curieri.curier_id%TYPE) IS    
-- cursor 1 pentru livrarile efectuate de un curier c_id
   SELECT livrare_id
   FROM livrari
   WHERE curier_id=c_id;

CURSOR comenzi_procesate_succes(c_id curieri.curier_id%TYPE) IS        
-- cursor 2 pentru comenzile procesate 'success'
   SELECT com.comanda_id comanda_id, SUM(p.NR_PRODUSE) nr_produse
   FROM comenzi com  JOIN procesare p ON com.comanda_id=p.comanda_id
                  JOIN livrari l ON l.LIVRARE_ID=p.LIVRARE_ID
   WHERE p.status='success' AND l.curier_id=c_id
   GROUP BY com.comanda_id;

nr_comenzi NUMBER:=0;
nr_produse_total NUMBER;
livrare_curenta_id LIVRARI.livrare_id%TYPE;
nr_curieri NUMBER;
no_curier EXCEPTION;
no_comanda EXCEPTION;

BEGIN

--verificam daca curierul exista
SELECT COUNT(*)INTO nr_curieri
FROM curieri c
WHERE c.curier_id=curier;

-- cazul in care nu exista curieri cu id-ul dat
IF nr_curieri=0 THEN
   RAISE no_curier;
END IF;

-- apelam cursorul 1
OPEN livrari_total(curier);
   LOOP
       FETCH livrari_total INTO livrare_curenta_id;
       EXIT WHEN livrari_total%NOTFOUND;
   END LOOP;

   IF livrari_total%rowcount=0 THEN    -- verificare daca are comenzi sau nu -> exceptie
        CLOSE livrari_total;
        RAISE no_comanda;
   END IF;

CLOSE livrari_total;

-- apelam cursorul 2
FOR i IN comenzi_procesate_succes(curier) LOOP

   SELECT com.nr_produse INTO nr_produse_total -- in nr_produse_total vom avea nr de produse din comanda plasata
   FROM comenzi com
   WHERE com.comanda_id=i.comanda_id;
  
   IF nr_produse_total=i.nr_produse THEN   -- verificam daca comanda a fost procesata integral
       nr_comenzi:=nr_comenzi+1;
   END IF;
END LOOP;

RETURN nr_comenzi;

-- definim exceptiile
EXCEPTION
   WHEN no_curier THEN
       RAISE_APPLICATION_ERROR(-20017,'Niciun curier inregistrat cu id-ul dat!');
    WHEN no_comanda THEN
       DBMS_OUTPUT.PUT_LINE('Curierul nu are deloc comenzi!');
       RETURN 0;
END;
/

BEGIN
   DBMS_OUTPUT.PUT_LINE('Curierul introdus a livrat ' || ex_functie(35) || ' comenzi integrale.');
   -- Curierul introdus a livrat 0 comenzi integrale.
END;
/


BEGIN
   DBMS_OUTPUT.PUT_LINE('Curierul introdus a livrat ' || ex_functie(30) || ' comenzi integrale.');
   -- Niciun curier inregistrat cu id-ul dat!
END;
/


BEGIN
   DBMS_OUTPUT.PUT_LINE('Curierul introdus a livrat ' || ex_functie(34) || ' comenzi integrale.');
   -- Curierul introdus a livrat 1 comenzi integrale.
END;
/


BEGIN
   DBMS_OUTPUT.PUT_LINE('Curierul introdus a livrat ' || ex_functie(33) || ' comenzi integrale.');
   --Curierul nu are deloc comenzi!
   --Curierul introdus a livrat 0 comenzi integrale.
END;
/

--9
--Periodic se acorda statutul de 'client premium' celor care au plasat comenzi în valoare de minim o anumitã suma, cu minim o comanda în ultima luna. În vederea acordarii acestui statut, verificati daca datele primite sunt valide(codul de identificare al clientului este valid, valoarea minima a comenzilor date este pozitiva) si, în caz afirmativ, afisati id-ul, numele, prenumele ?i valoarea lor totalã.

CREATE OR REPLACE PROCEDURE proc_ex9 (client_nume PERS_FIZICE.nume%TYPE, valoare_totala FLOAT) IS

c_id clienti.client_id%TYPE;
c_prenume pers_fizice.prenume%TYPE;
c_nume pers_fizice.nume%TYPE;
email clienti.email%TYPE;
data_co comenzi.data_comanda%TYPE;
pret_total FLOAT;

client_invalid EXCEPTION;
valoare_invalida EXCEPTION;

BEGIN
    IF valoare_totala <= 0 THEN
        RAISE valoare_invalida;      -- tratam cazul in care valoarea introdusa pentru suma este negativa sau =0
    END IF;

    SELECT c.client_id, pf.prenume, pf.nume, c.email, max(co.data_comanda), SUM(co.pret_colet + tl.tarif + round((co.cod_greutate * co.pret_colet)/100,2))
    INTO c_id, c_prenume, c_nume, email, data_co, pret_total
    FROM pers_fizice pf JOIN clienti c ON (c.client_id = pf.client_id)
                        JOIN comenzi co ON (co.client_id = c.client_id)
                        JOIN coduri_greutate cg ON (cg.cod_greutate = co.cod_greutate)
                        JOIN tarife_livrare tl ON (tl.cod_identificare_tarif = co.cod_identificare_tarif)
    WHERE LOWER(pf.nume) = LOWER(client_nume)
    GROUP BY c.client_id, pf.prenume, pf.nume, c.email;

    IF pret_total < valoare_totala  OR months_between(sysdate,data_co) <= 1  THEN     -- tratam cazul in care clientul nu corespunde criteriilor
        RAISE client_invalid;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Clientul cu id-ul ' || c_id ||'(' || c_nume || ' ' || c_prenume || '), email: ' || email
                         || ' a efectuat comenzi cu o valoare totala de ' || pret_total || ' RON.');

EXCEPTION
   WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'Clientul nu exista in baza de date!');
   WHEN TOO_MANY_ROWS THEN
       RAISE_APPLICATION_ERROR(-20001,'Exista mai multi clienti cu acest id!');
   WHEN client_invalid THEN
        DBMS_OUTPUT.PUT_LINE('Clientul este invalid(nu corespunde criteriilor de acordare a statutului de client premium)');
   WHEN valoare_invalida THEN
       RAISE_APPLICATION_ERROR(-20002,'Valoarea este invalida. Se astepta un numar pozitiv!');
END;
/

BEGIN
    proc_ex9('Iordache', 0); --Valoarea este invalida. Se astepta un numar pozitiv!
END;
/

BEGIN
    proc_ex9('Iordache', 100);  -- Clientul cu id-ul 10006(Iordache Beatrice), email: iordache_bety@yahoo.com a efectuat comenzi cu o valoare totala de 1258,3 RON.
END;
/

BEGIN
    proc_ex9('Corneanu', 100);  -- Clientul nu exista in baza de date!
END;
/

BEGIN
    proc_ex9('Ionescu', 500);  -- Clientul este invalid(nu corespunde criteriilor de acordare a statutului de client premium)
END;
/

BEGIN
    proc_ex9('Popescu', 100);  --Exista mai multi clienti cu acest id!
END;
/

--10
--Deoarece compania de curierat a avut încasãri mai mici în ultima jumãtate de an, a decis facã reduceri de buget.În urma acestei decizii, s-a hotarat ca numãrul de prime oferite sa nu depaseasca 4, dar sa existe cel pu?in una pentru a stimula angaja?ii periodic. Crea?i un trigger pentru a solu?iona acest aspect.


CREATE OR REPLACE TRIGGER trigger10
   BEFORE INSERT OR DELETE ON CURIERI
DECLARE
nr_prime NUMBER;

BEGIN

select count(prima_id) into nr_prime from CURIERI;

IF DELETING AND nr_prime=0 THEN
   RAISE_APPLICATION_ERROR(-20005, 'Trebuie sa existe minim o prima!');
ELSIF INSERTING AND nr_prime=4 THEN
   RAISE_APPLICATION_ERROR(-20006, 'Numarul primelor acordate trebuie sa fie maxim 4!');
END IF;
END;
/

INSERT INTO CURIERI VALUES(36, 'Georgescu', 'Irinel', 07325262521, 21, TO_DATE('2022-08-17', 'YYYY-MM-DD HH24:MI:SS'),3200,2,220, TO_DATE('2022-08-17', 'YYYY-MM-DD HH24:MI:SS'));

--11
--Sã se afi?eze o eroare atunci când în urma modificãrii salariului sau bonusului pentru un curier care  lucreazã de mai pu?in de 5 ani, acesta are un venit total(salariu_brut + salariu_brut*procent/100+prima_ocazionala)  mai mare decat cel mediu.

CREATE OR REPLACE TRIGGER trigger11
    BEFORE UPDATE OF SALARIU_BRUT, PRIMA_ID, PRIMA_OCAZIONALA ON CURIERI
    FOR EACH ROW
DECLARE

PRAGMA autonomous_transaction; --pt mutating table
d_ang date ;
salariu_mediu FLOAT;
procent_nou PRIME_PERFORMANTA.PROCENT%TYPE;
venit FLOAT;
exceptie EXCEPTION;

BEGIN
            SELECT data_angajare INTO d_ang FROM curieri where CURIER_ID = :NEW.curier_id;

            SELECT AVG(c.SALARIU_BRUT+(nvl(p.procent,0)*c.SALARIU_BRUT)/100+c.PRIMA_OCAZIONALA) INTO salariu_mediu
            FROM CURIERI c
            LEFT JOIN PRIME_PERFORMANTA p USING(prima_id);

            IF :NEW.prima_id is null THEN
                procent_nou:=0;
                venit:=:NEW.salariu_brut + :NEW.prima_ocazionala;
            ELSE
                SELECT PROCENT INTO procent_nou
                FROM  PRIME_PERFORMANTA
                WHERE prima_id =:NEW.prima_id;

                venit:=:NEW.salariu_brut+ (:NEW.salariu_brut*procent_nou)/100 + :NEW.prima_ocazionala;
             END IF;

            IF venit > salariu_mediu OR months_between(sysdate, d_ang)< 60 THEN
                    RAISE exceptie;
            END IF;
EXCEPTION
    WHEN exceptie THEN
        RAISE_APPLICATION_ERROR(-20017, 'Acest curier nu se califica pentru prima de performanta si pentru un venit mai mare!');
END;
/

UPDATE curieri
SET prima_id=null 
WHERE curier_id=35; -- Acest curier nu se califica pentru prima de performanta si pentru un venit mai mare!

UPDATE curieri
SET PRIMA_ID=3
WHERE curier_id=33;  -- Acest curier nu se califica pentru prima de performanta si pentru un venit mai mare!

rollback;

UPDATE curieri
SET prima_id=null
WHERE curier_id=100; -- => 0 rows updated


--12
--Înregistra?i toate opera?iile LDD efectuate asupra schemei folosind un tabel auxiliar audit_table.

CREATE TABLE audit_table
(
    event_id NUMBER PRIMARY KEY,
    username VARCHAR2(100) NOT NULL,
    date_event DATE NOT NULL,
    event VARCHAR2(50) NOT NULL,
    object_name VARCHAR2(100) NOT NULL
);

CREATE SEQUENCE  seq_audit_id  MINVALUE 1 MAXVALUE 9999999 INCREMENT BY 1 START WITH 1 NOCACHE ;

CREATE OR REPLACE PROCEDURE proc_add(event_id NUMBER, username VARCHAR2, date_event DATE, event VARCHAR2, object_name VARCHAR2) IS
BEGIN
    INSERT INTO audit_table VALUES(event_id,username,date_event,event,object_name);
END;
/

CREATE OR REPLACE TRIGGER trigger12
    AFTER DROP OR ALTER OR CREATE ON SCHEMA
BEGIN
    proc_add(seq_audit_id.NEXTVAL, user, sysdate, ora_sysevent, SYS.dictionary_obj_name);
END;
/

SELECT * FROM audit_table;


--13
CREATE OR REPLACE PACKAGE ex_package IS

PROCEDURE ex_colectii;  --6
PROCEDURE ex_cursoare;   --7
FUNCTION ex_functie(curier curieri.curier_id%TYPE) RETURN NUMBER;   --8
PROCEDURE proc_ex9  (client_nume PERS_FIZICE.nume%TYPE, valoare_totala FLOAT); --9
PROCEDURE proc_add(event_id NUMBER, username VARCHAR2, date_event DATE, event VARCHAR2, object_name VARCHAR2);
END ex_package;
/

CREATE OR REPLACE PACKAGE BODY ex_package  IS
--6
PROCEDURE ex_colectii IS
  TYPE t_judete IS TABLE of adrese_livrare.judet%type INDEX BY PLS_INTEGER; --index-by-table
   v_judete t_judete;
   TYPE t_nr_comenzi IS TABLE OF NUMBER INDEX BY PLS_INTEGER; --index-by-table
   v_nr_comenzi t_nr_comenzi;
  TYPE t_orase IS TABLE OF ADRESE_LIVRARE.oras%TYPE; --nested table
  TYPE t_total_orase IS TABLE OF t_orase; --nested table
  v_orase t_total_orase:=t_total_orase();
   nr_judete NUMBER;
  nr_orase NUMBER;
  
BEGIN
  SELECT DISTINCT ad.judet, COUNT(*)
  BULK COLLECT INTO v_judete, v_nr_comenzi
  FROM comenzi c JOIN ADRESE_LIVRARE ad ON c.adresa_livrare_id=ad.ADRESA_id
  GROUP BY ad.judet;

  nr_judete:=v_judete.COUNT;

  FOR i IN 1..nr_judete LOOP -- pentru fiecare judet
      v_orase.EXTEND;

      SELECT DISTINCT ad.oras
      BULK COLLECT INTO v_orase(i)
      FROM comenzi c JOIN ADRESE_LIVRARE ad ON c.adresa_livrare_id=ad.adresa_id
      WHERE ad.judet=v_judete(i);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Detalii comenzi pe jude?e: ');


  FOR i IN 1..nr_judete LOOP -- pentru fiecare judet
      DBMS_OUTPUT.PUT(v_judete(i) || ' are ' || v_nr_comenzi(i));
      IF v_nr_comenzi(i)=1 THEN
          DBMS_OUTPUT.PUT(' comanda in ');
      ELSE
          DBMS_OUTPUT.PUT(' comenzi in ');
      END IF;

        DBMS_OUTPUT.PUT(v_orase(i).COUNT);
        IF v_orase(i).COUNT=1 THEN
            DBMS_OUTPUT.PUT(' oras(');
        ELSE
            DBMS_OUTPUT.PUT(' orase(');
        END IF;

      nr_orase:=v_orase(i).COUNT;
      FOR j IN 1..nr_orase-1 LOOP
          DBMS_OUTPUT.PUT( v_orase(i)(j)|| ', ');
      END LOOP;
      DBMS_OUTPUT.PUT( v_orase(i)(nr_orase)|| ').');

      DBMS_OUTPUT.NEW_LINE;
END LOOP;
END ex_colectii;

--7
PROCEDURE ex_cursoare IS

an number(4) := &p_an;

-- cursor parametrizat
CURSOR c1_ex_cursoare(an NUMBER) IS
          SELECT c.curier_id curier_id, c.prenume prenume, c.nume nume, a.data_accident data_accident, a.cost_daune cost_daune, m.masina_id masina_id,
                 m.marca marca, m.model model, c.data_angajare data_angajare, istm.data_preluare_masina data_preluare_masina, istm.data_predare_masina, c.data_preluare_masina data_preluare_masina2
          FROM curieri c JOIN accidente a ON c.curier_id=a.curier_id
                         JOIN masini m ON a.masina_id=m.masina_id
                         LEFT JOIN istoric_masini istm ON (a.masina_id=istm.masina_id AND a.curier_id=istm.curier_id
                                       AND a.data_accident<=istm.DATA_PREDARE_MASINA AND a.DATA_ACCIDENT>=istm.DATA_PRELUARE_MASINA )
           WHERE EXTRACT(YEAR FROM a.data_accident) = an;
           
curenta VARCHAR2(50);
top number(1) := 0;


BEGIN
DBMS_OUTPUT.PUT_LINE('Top 3 accidente 2022 conform pagubelor');
--ciclu cursor cu subcereri
FOR i IN (SELECT c.curier_id id, c.prenume p, c.nume n, a.data_accident da, a.cost_daune cd, c.salariu_brut sb
        FROM curieri c JOIN accidente a ON c.curier_id=a.curier_id
        ORDER BY a.cost_daune DESC)
    LOOP
        DBMS_OUTPUT.PUT_LINE('Data accident: ' || i.da || '; Sofer responsabil:' || i.id || '; Daune materiale:' || i.cd);
        top := top+1;
        EXIT WHEN top = 3;
    END LOOP;

DBMS_OUTPUT.PUT_LINE('Accidente inregistrate in anul ' || an);
FOR i IN c1_ex_cursoare(an) LOOP --ciclu cursor

   IF i.data_predare_masina < i.data_accident THEN
       curenta:='masina curenta a curierului ';
   ELSE
       curenta:='masina anterioara a curierului ';
   END IF;
   DBMS_OUTPUT.PUT_LINE('Ma?ina cu numarul de identificare(id) ' || i.masina_id || ' (' || i.marca || ' ' || i.model || '),' || curenta || i.nume || ' ' || i.prenume || ', avand id-ul ' || i.curier_id || ', a fost implicata intr-un accident in luna ' || extract(month from i.data_accident) || '.');
END LOOP;

END ex_cursoare;


--8
FUNCTION ex_functie(curier curieri.curier_id%TYPE) RETURN NUMBER IS

CURSOR livrari_total(c_id curieri.curier_id%TYPE) IS    
-- cursor 1 pentru livrarile efectuate de un curier c_id
   SELECT livrare_id
   FROM livrari
   WHERE curier_id=c_id;

CURSOR comenzi_procesate_succes(c_id curieri.curier_id%TYPE) IS        
-- cursor 2 pentru comenzile procesate 'success'
   SELECT com.comanda_id comanda_id, SUM(p.NR_PRODUSE) nr_produse
   FROM comenzi com  JOIN procesare p ON com.comanda_id=p.comanda_id
                  JOIN livrari l ON l.LIVRARE_ID=p.LIVRARE_ID
   WHERE p.status='success' AND l.curier_id=c_id
   GROUP BY com.comanda_id;

nr_comenzi NUMBER:=0;
nr_produse_total NUMBER;
livrare_curenta_id LIVRARI.livrare_id%TYPE;
nr_curieri NUMBER;
no_curier EXCEPTION;
no_comanda EXCEPTION;

BEGIN

--verificam daca curierul exista
SELECT COUNT(*)INTO nr_curieri
FROM curieri c
WHERE c.curier_id=curier;

-- cazul in care nu exista curieri cu id-ul dat
IF nr_curieri=0 THEN
   RAISE no_curier;
END IF;

-- apelam cursorul 1
OPEN livrari_total(curier);
   LOOP
       FETCH livrari_total INTO livrare_curenta_id;
       EXIT WHEN livrari_total%NOTFOUND;
   END LOOP;

   IF livrari_total%rowcount=0 THEN    -- verificare daca are comenzi sau nu -> exceptie
        CLOSE livrari_total;
        RAISE no_comanda;
   END IF;

CLOSE livrari_total;

-- apelam cursorul 2
FOR i IN comenzi_procesate_succes(curier) LOOP

   SELECT com.nr_produse INTO nr_produse_total -- in nr_produse_total vom avea nr de produse din comanda plasata
   FROM comenzi com
   WHERE com.comanda_id=i.comanda_id;
  
   IF nr_produse_total=i.nr_produse THEN   -- verificam daca comanda a fost procesata integral
       nr_comenzi:=nr_comenzi+1;
   END IF;
END LOOP;

RETURN nr_comenzi;

-- definim exceptiile
EXCEPTION
   WHEN no_curier THEN
       RAISE_APPLICATION_ERROR(-20017,'Niciun curier inregistrat cu id-ul dat!');
    WHEN no_comanda THEN
       DBMS_OUTPUT.PUT_LINE('Curierul nu are deloc comenzi!');
       RETURN 0;
END ex_functie;

--9
PROCEDURE proc_ex9 (client_nume PERS_FIZICE.nume%TYPE, valoare_totala FLOAT) IS

c_id clienti.client_id%TYPE;
c_prenume pers_fizice.prenume%TYPE;
c_nume pers_fizice.nume%TYPE;
email clienti.email%TYPE;
data_co comenzi.data_comanda%TYPE;
pret_total FLOAT;

client_invalid EXCEPTION;
valoare_invalida EXCEPTION;

BEGIN
    IF valoare_totala <= 0 THEN
        RAISE valoare_invalida;      -- tratam cazul in care valoarea introdusa pentru suma este negativa sau =0
    END IF;

    SELECT c.client_id, pf.prenume, pf.nume, c.email, max(co.data_comanda), SUM(co.pret_colet + tl.tarif + round((co.cod_greutate * co.pret_colet)/100,2))
    INTO c_id, c_prenume, c_nume, email, data_co, pret_total
    FROM pers_fizice pf JOIN clienti c ON (c.client_id = pf.client_id)
                        JOIN comenzi co ON (co.client_id = c.client_id)
                        JOIN coduri_greutate cg ON (cg.cod_greutate = co.cod_greutate)
                        JOIN tarife_livrare tl ON (tl.cod_identificare_tarif = co.cod_identificare_tarif)
    WHERE LOWER(pf.nume) = LOWER(client_nume)
    GROUP BY c.client_id, pf.prenume, pf.nume, c.email;

    IF pret_total < valoare_totala  OR months_between(sysdate,data_co) <= 1  THEN     -- tratam cazul in care clientul nu corespunde criteriilor
        RAISE client_invalid;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Clientul cu id-ul ' || c_id ||'(' || c_nume || ' ' || c_prenume || '), email: ' || email
                         || ' a efectuat comenzi cu o valoare totala de ' || pret_total || ' RON.');

EXCEPTION
   WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'Clientul nu exista in baza de date!');
   WHEN TOO_MANY_ROWS THEN
       RAISE_APPLICATION_ERROR(-20001,'Exista mai multi clienti cu acest id!');
   WHEN client_invalid THEN
        DBMS_OUTPUT.PUT_LINE('Clientul este invalid(nu corespunde criteriilor de acordare a statutului de client premium)');
   WHEN valoare_invalida THEN
       RAISE_APPLICATION_ERROR(-20002,'Valoarea este invalida. Se astepta un numar pozitiv!');
END proc_ex9;


PROCEDURE proc_add(event_id NUMBER, username VARCHAR2, date_event DATE, event VARCHAR2, object_name VARCHAR2) IS
BEGIN
    INSERT INTO audit_table VALUES(event_id,username,date_event,event,object_name);
END proc_add;


END ex_package;
/

--exemplu apelare procedura din pachet
BEGIN
    ex_package.ex_colectii();
END;
/

--14
--Verifica?i dacã profitul pe luna decembrie a fost mai mare decat cel din noiembrie. 
--În caz afirmativ, mariti salariile primilor 3 curieri care au livrat cele mai multe pachete cu 15% ?i afi?a?i informa?ii despre ace?tia (id, nume, numãr de pachete livrate); 
--altfel, mãri?i tarifele de livrare cu 20% ?i afi?a?i care ar fi fost profitul pe decembrie cu aceste noi preturi.

CREATE OR REPLACE PACKAGE package_ex14 IS
    TYPE curieri_obj_type IS RECORD
    (
        curier_id NUMBER,
        nr_produse NUMBER,
        nume VARCHAR2(50)
    );
    TYPE top_curieri IS TABLE OF curieri_obj_type;
   
    FUNCTION profit_comenzi(luna NUMBER) RETURN NUMBER;
    FUNCTION get_top_curieri RETURN top_curieri;
    PROCEDURE marire_salarii;
    PROCEDURE marire_tarife_livrare;
    PROCEDURE aplica;

END package_ex14;
/

CREATE OR REPLACE PACKAGE BODY package_ex14 IS

    FUNCTION profit_comenzi(luna NUMBER) RETURN NUMBER IS
    total_profit NUMBER;
    no_comanda EXCEPTION;
    BEGIN
		--calculam profitul pe o anumita luna
            SELECT SUM((co.pret_colet*cg.supracost_procent)/100 + tl.tarif)
            INTO total_profit
            FROM comenzi co JOIN coduri_greutate cg USING (cod_greutate) 
                            JOIN tarife_livrare tl USING (cod_identificare_tarif) 
            WHERE EXTRACT(MONTH FROM (co.data_comanda))=luna;
            
    IF total_profit IS NULL THEN 
        RAISE no_comanda;	
--tratam cazul in care nu a fost inregistrat profit pe o anumita luna
    END IF;    
    
    RETURN total_profit;        
            
    EXCEPTION
        WHEN no_comanda THEN 
            DBMS_OUTPUT.PUT_LINE('În aceasta luna nu s-a plasat nicio comandã!');
            RETURN 0;
    
    END profit_comenzi;
    
    FUNCTION get_top_curieri RETURN top_curieri IS
    CURSOR c_curieri IS
				--determinam top 3 curieri
                       SELECT t.curier_id, t.nume, SUM(t.nr_produse) total_colete_livrate
                       FROM
                      (SELECT curier_id, nume, livrare_id, COUNT(*) nr_produse
                      FROM livrari JOIN procesare USING (livrare_id)
                                     JOIN curieri USING(curier_id)
                      WHERE status='success'        
                      GROUP BY livrare_id, curier_id, nume) t
                      GROUP BY t.curier_id, t.nume
                      ORDER BY 3 DESC
                      FETCH FIRST 3 ROWS ONLY;
                        
    j NUMBER:=0;
    v_top_curieri top_curieri:=top_curieri();  
            
    BEGIN
    
    FOR i IN c_curieri LOOP
        j:=j+1;
        v_top_curieri.EXTEND;
        v_top_curieri(j):=curieri_obj_type(i.curier_id, i.total_colete_livrate, i.nume);
    END LOOP;
    
    RETURN v_top_curieri;
    
END get_top_curieri;
        
    
--procedura care mareste salariile curierilor si afiseaza aceasta ‘operatiune’
    PROCEDURE marire_salarii IS
    v_curieri top_curieri;
    BEGIN
    
    v_curieri:=get_top_curieri;
    
    FOR i IN 1..v_curieri.COUNT LOOP
        UPDATE curieri SET salariu_brut=ROUND(salariu_brut*1.15)
        WHERE curier_id=v_curieri(i).curier_id;
        
        DBMS_OUTPUT.PUT_LINE('Curierului cu id-ul ' || v_curieri(i).curier_id || '( ' || v_curieri(i).nume
                             || ') i s-a mãrit salariul cu 15%, deoarece s-a clasat in top 3 cei mai buni curieri livând '
                             || v_curieri(i).nr_produse|| ' colete.');
        
    END LOOP;
    
    END marire_salarii;
    
--procedura care mareste tarifele
    PROCEDURE marire_tarife_livrare IS
    BEGIN
        UPDATE tarife_livrare
        SET tarif=tarif*1.25;
         
    END marire_tarife_livrare;
    
    
    PROCEDURE aplica IS
    v_profit_nov FLOAT;
    v_profit_dec FLOAT;
    
    BEGIN
        v_profit_nov:=profit_comenzi(11);
        v_profit_dec:=profit_comenzi(12);
        
	– conditie comparare profit => marire salarii/tarife+afisare
        IF v_profit_dec>v_profit_nov THEN 
            marire_salarii;
        ELSE 
            marire_tarife_livrare;
            DBMS_OUTPUT.PUT_LINE('Dupa aplicarea schimbarilor, profitul va fi ' || profit_comenzi(11) || ' in loc de'
                                  || v_profit_dec || '.');
        END IF;
    
    END aplica;
    
END package_ex14;
/

BEGIN
    package_ex14.aplica();  
    -- (trigger11) Acest curier nu se califica pentru prima de performanta si pentru un venit mai mare!

    -- drop trigger trigger11;
    --Curierului cu id-ul 34( Andronic) i s-a mãrit salariul cu 15%, deoarece s-a clasat in top 3 cei mai buni curieri livând 2 colete.
    --Curierului cu id-ul 32( Ionescu) i s-a mãrit salariul cu 15%, deoarece s-a clasat in top 3 cei mai buni curieri livând 2 colete.
    --Curierului cu id-ul 35( Ilie ) i s-a mãrit salariul cu 15%, deoarece s-a clasat in top 3 cei mai buni curieri livând 1 colete.

END;
/

        --Pentru:
--        v_profit_nov:=profit_comenzi(9);
--        v_profit_dec:=profit_comenzi(10);
--În aceasta luna nu s-a plasat nicio comandã!
--Acest curier nu se califica pentru prima de performanta si pentru un venit mai mare!
