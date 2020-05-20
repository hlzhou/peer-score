"""Extract cohort outcomes and join with cohort features in the database tables created by eicu_extraction.sql. 

After the eICU cohort and feature tables have been created, run this script to output the data into a cleaner csv.

After joining the cohort with its features and outcomes, this script creates a vector corresponding to 
0, 24, and 48 hours after admission into the ICU. All features values are taken as the latest feature up
until that point in that patient's hospital admission (or null if there are none up until that point). 
Time to outcome event is computed as the time of the first event relative to the start of the corresponding 
day (at 0, 24, and 48 hours).
"""

import psycopg2
import pandas as pd


VP_STRINGS = (  # vasopressor strings
    'cardiovascular|shock|vasopressors|norepinephrine > 0.1 micrograms/kg/min',
    'cardiovascular|shock|vasopressors|dopamine >15 micrograms/kg/min',
    'cardiovascular|shock|vasopressors|epinephrine > 0.1 micrograms/kg/min',
    'cardiovascular|shock|vasopressors',
    'cardiovascular|shock|vasopressors|vasopressin',
    'cardiovascular|shock|vasopressors|dopamine  5-15 micrograms/kg/min',
    'cardiovascular|shock|vasopressors|phenylephrine (Neosynephrine)',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|norepinephrine <= 0.1 micrograms/kg/min',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|norepinephrine > 0.1 micrograms/kg/min',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|phenylephrine (Neosynephrine)',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|dopamine 5-15 micrograms/kg/min',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|epinephrine > 0.1 micrograms/kg/min',
    'neurologic|therapy for controlling cerebral perfusion pressure|vasopressors|dopamine > 15 micrograms/kg/min')

MV_STRINGS = (  # mechanical ventilation strings
  'pulmonary|ventilation and oxygenation|mechanical ventilation',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|tidal volume < 6 ml/kg',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|pressure controlled',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|assist controlled',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|synchronized intermittent',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|tidal volume 6-10 ml/kg',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|volume controlled',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|non-invasive ventilation',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|pressure support',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|permissive hypercapnea',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|tidal volume > 10 ml/kg',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|non-invasive ventilation|face mask',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|volume assured',
  'pulmonary|ventilation and oxygenation|mechanical ventilation|non-invasive ventilation|nasal mask')


class Database:
  def __init__(self, hostname, username, password, dbname):
    self._hostname = hostname
    self._username = username
    self._password = password
    self._dbname = dbname

    self.conn = self._connect()

  def _connect(self) :
    conn = psycopg2.connect(host=self._hostname,
                            user=self._username,
                            password=self._password,
                            dbname=self._dbname)
    cur = conn.cursor()
    cur.execute('set search_path to eicu_crd;')
    print('set search_path to eicu_crd;')
    return conn

  def get_conn(self):
    return self.conn

  def get_table_names(self, name):
      command = "select column_name from information_schema.columns " \
                "where table_schema=\'eicu_crd\' and table_name=\'{}\';".format(name)
      rows = self.do_query(command)
      names = [i[0] for i in rows]
      print('names:\n', names)
      return names

  def do_query(self, command, fetch=True, commit=False) :
      print('============= COMMAND: ==============\n'
            '{}\n============================================'.format(command))
      cur = self.conn.cursor()
      cur.execute(command)
      if commit:
        self.conn.commit()
      if fetch:
        rows = cur.fetchall()
        return rows


def main():
  cohort = 'pna_nonbacterial_cohort'
  shortname = 'c2'
  print('COHORT: {}\tSHORTNAME: {}'.format(cohort, shortname))

  ## Connect to database
  hostname = 'localhost'
  username = 'postgres'
  password = 'postgres'
  dbname = 'eicu'

  db = Database(hostname, username, password, dbname)
  conn = db.get_conn()

  ## Create outcome and feature dataframes

  # create outcome indicators
  print("Creating indicators for outcomes mv and vp...")  
  db.do_query("create temporary table {shortname}_treat0 as "
              "select t.patientunitstayid as patientunitstayid, treatmentid, treatmentoffset, treatmentstring, "
              "case when treatmentstring in {vpstr} then 1 else 0 end as vp, "
              "case when treatmentstring in {mvstr} then 1 else 0 end as mv "
              "from treatment as t "
              "join {cohort} as c "
              "on t.patientunitstayid = c.patientunitstayid;".format(shortname=shortname,
                                                                     vpstr=VP_STRINGS,
                                                                     mvstr=MV_STRINGS,
                                                                     cohort=cohort), fetch=False, commit=False)
  outcome_tablename = '{}_treat'.format(shortname)
  db.do_query("drop table if exists {};".format(outcome_tablename), fetch=False, commit=True)
  db.do_query("CREATE TABLE {} AS "
              "SELECT patientunitstayid, treatmentoffset, "
              "MAX(vp) as vasopressor_indicator, "
              "MAX(mv) as ventilator_indicator "
              "FROM {}_treat0 t "
              "GROUP BY t.patientunitstayid, treatmentoffset;".format(outcome_tablename, shortname), fetch=False, commit=False)

  print('Some entries in {}: '.format(outcome_tablename),
        db.do_query('select * from {} limit 2;'.format(outcome_tablename), fetch=True, commit=False))

  # join eICU patient table with our cohort table
  db.do_query('drop table if exists {}_patient;'.format(shortname), fetch=False, commit=True)
  db.do_query('CREATE TABLE {shortname}_patient AS '
              'SELECT p.patientunitstayid as patientunitstayid, '
              'patienthealthsystemstayid, hospitaladmitoffset, unitdischargeoffset '
              'FROM patient p JOIN {cohort} c on p.patientunitstayid=c.patientunitstayid;'.format(shortname=shortname,
                                                                                                  cohort=cohort),
              fetch=False, commit=True)

  print('Some patient rows: ',
        db.do_query('select * from {}_patient limit 10;'.format(shortname), fetch=True))
  print("Distinct patientunitstayid's: ",
        db.do_query('select count(distinct(patientunitstayid)) from {shortname}_patient;'.format(shortname=shortname), fetch=True))
  print("Distinct patienthealthsystemstayid's: ",
        db.do_query("select count(distinct(patienthealthsystemstayid)) from {shortname}_patient;".format(shortname=shortname), fetch=True))
  print('Rows in {}_patient: '.format(shortname),
        db.do_query('select count(*) from {shortname}_patient;'.format(shortname=shortname), fetch=True))

  # extract patient death
  db.do_query('drop table if exists {}_death0;'.format(shortname), fetch=False, commit=True)

  command = "create table {shortname}_death0 " \
            "as select coalesce(r.patientunitstayid, c.patientunitstayid) as patientunitstayid, " \
            "r.actualicumortality " \
            "from apachepatientresult r " \
            "join {cohort} c on r.patientunitstayid=c.patientunitstayid " \
            "where r.apacheversion like \'%IVa%\';".format(shortname=shortname, cohort=cohort)
  db.do_query(command, fetch=False, commit=True)
  db.do_query('drop table if exists {}_death;'.format(shortname), fetch=False, commit=True)

  command = "create table {shortname}_death          " \
            "as select patientunitstayid,           " \
            "case              " \
            "when r.actualicumortality like \'%ALIVE%\' then 0 else 1           " \
            "end as deceased_indicator           " \
            "from {shortname}_death0 r;".format(shortname=shortname)
  db.do_query(command, fetch=False, commit=True)
  print(db.do_query('select count(*) from {}_death;'.format(shortname), fetch=True))
  print(db.do_query('select count(distinct(patientunitstayid)) from {}_death;'.format(shortname), fetch=True))

  db.do_query('drop table if exists {}_patientdeath0;'.format(shortname), fetch=False, commit=True)

  command = "create table {shortname}_patientdeath0 " \
            "as select coalesce(p.patientunitstayid, c.patientunitstayid) as patientunitstayid, " \
            "case " \
            "when lower(p.unitDischargeStatus) like '%expired%' then 1 else 0 " \
            "end as deceased_indicator " \
            "from patient p " \
            "join {cohort} c on p.patientunitstayid=c.patientunitstayid;".format(shortname=shortname, cohort=cohort)
  db.do_query(command, fetch=False, commit=True)
  db.do_query('drop table if exists {}_patientdeath;'.format(shortname), fetch=False, commit=True)

  command = "create table {shortname}_patientdeath          " \
            "as select patientunitstayid,           " \
            "MAX(deceased_indicator) as deceased_indicator           " \
            "from {shortname}_patientdeath0 group by patientunitstayid;".format(shortname=shortname)
  db.do_query(command, fetch=False, commit=True)

  # extract 1st ICU visits
  db.do_query('drop table if exists {shortname}_firstpatientunitstayid;'.format(shortname=shortname),
              fetch=False, commit=True)
  command = 'create table {shortname}_firstpatientunitstayid as select patientunitstayid from ' \
            '(select patienthealthsystemstayid, ' \
            'max(hospitaladmitoffset) as hospitaladmitoffset ' \
            'from {shortname}_patient ' \
            'group by patienthealthsystemstayid) t ' \
            'join {shortname}_patient c ' \
            'on t.patienthealthsystemstayid=c.patienthealthsystemstayid' \
            ' and t.hospitaladmitoffset=c.hospitaladmitoffset;'.format(shortname=shortname)
  db.do_query(command, fetch=False, commit=True)
  print('Count of firstpatientunitstayids: ',
        db.do_query('select count(*) from {shortname}_firstpatientunitstayid'.format(shortname=shortname)))

  # join together the feature tables
  db.do_query('drop table if exists {}_features0;'.format(shortname), fetch=False, commit=True)
  db.do_query("CREATE table {shortname}_features0 as "
              "SELECT COALESCE(d.patientunitstayid, l.patientunitstayid, v.patientunitstayid, "
              "n.patientunitstayid, c.patientunitstayid, a.patientunitstayid) as patientunitstayid, "
              "COALESCE(l.t_offset, v.t_offset, n.t_offset, c.t_offset, a.t_offset) as t_offset, "
              "COALESCE(l.temperature, v.temperature, n.temperature) as temperature, "
              "coalesce(cast(n.bp_systolic as float), v.bp_systolic) as bp_systolic, "
              "coalesce(cast(n.bp_diastolic as float), v.bp_diastolic) as bp_diastolic, "
              "coalesce(cast(n.bp_mean as float), v.bp_mean) as bp_mean_arterial, "
              "rbcs, wbc, platelets, hemoglobin, hct, rdw, mcv, mch, mchc, "
              "neutrophils, lymphocytes, monocytes, eosinophils, basophils, "
              "bun, ph, sodium, glucose, pao2, fio2, ldh, crp, direct_bilirubin, total_bilirubin, total_protein, "
              "albumin, ferritin, pt, ptt, fibrinogen, ast, alt, creatinine, troponin, alkaline_phosphatase, "
              "bands, bicarbonate, calcium, chloride, potassium, "
              "d.gender, d.age, d.ethnicity, "
              "v.heart_rate, v.sao2, "
              "COALESCE(CAST(n.respiratory_rate AS FLOAT), CAST(v.respiratory_rate AS FLOAT)) as respiratory_rate, " 
              "COALESCE(n.gcs, n.gcs2) as gcs, "
              "c.smoking, "
              "COALESCE(c.pleural_effusion, 0) as pleural_effusion, "
              "COALESCE(a.orientation,  n.gcs_orientation) as orientation, "
              "d.nursing_home as nursing_home, "
              "r.chest_xray as chest_xray "
              "FROM {shortname}_demographics d "
              "FULL JOIN {shortname}_labs l "
              "ON d.patientunitstayid = l.patientunitstayid "
              "FULL JOIN {shortname}_vitals v "
              "ON l.t_offset= v.t_offset and v.patientunitstayid = l.patientunitstayid "
              "FULL JOIN {shortname}_nurse_charting n "
              "ON n.t_offset= v.t_offset and v.patientunitstayid = n.patientunitstayid "
              "FULL JOIN {shortname}_comorbidities c "
              "ON c.t_offset= n.t_offset and c.patientunitstayid = n.patientunitstayid "
              "FULL JOIN {shortname}_amt a "
              "ON a.t_offset= c.t_offset and a.patientunitstayid=c.patientunitstayid "
              "FULL JOIN {shortname}_xray r "
              "ON r.t_offset= a.t_offset and r.patientunitstayid=a.patientunitstayid "
              "ORDER BY patientunitstayid, t_offset;".format(shortname=shortname),
              fetch=False, commit=True)

  print('features0: ',
        db.do_query('select * from {}_features0 limit 2;'.format(shortname), fetch=True))
  print(db.do_query('select count(distinct(patientunitstayid)) from {}_features0;'.format(shortname), fetch=True))
  print('finishing merging features.')

  db.do_query('drop table if exists {}_features;'.format(shortname), fetch=False, commit=True)

  # create table of first patient ICU stays joined with the corresponding features
  db.do_query("create table {shortname}_features as "
              "select f.* from {shortname}_features0 f "
              "join {shortname}_firstpatientunitstayid p on p.patientunitstayid=f.patientunitstayid;".format(shortname=shortname),
              fetch=False, commit=True)
  print(db.do_query('select count(distinct(patientunitstayid)) from {}_features'.format(shortname), fetch=True))
  print(db.do_query('select * from {}_features limit(5);'.format(shortname), fetch=True))
  
  a = db.do_query('drop table if exists {}_outs0;'.format(shortname), fetch=False, commit=True)
  db.do_query("create table {shortname}_outs0           "
              "as select           "
              "coalesce(t.patientunitstayid, p.patientunitstayid, d.patientunitstayid) as patientunitstayid,           "
              "t.vasopressor_indicator, t.ventilator_indicator,           "
              "p.unitdischargeoffset/1440.0 as censor_or_deceased_days,           "
              "d.deceased_indicator,           "
              "case               "
              "when vasopressor_indicator=1 then t.treatmentoffset/1440.0 else p.unitdischargeoffset/1440.0           "
              "end as censor_or_vasopressor_days,           "
              "case               "
              "when ventilator_indicator=1 then t.treatmentoffset/1440.0 else p.unitdischargeoffset/1440.0           "
              "end as censor_or_ventilator_days           "
              "from {shortname}_treat as t           "
              "full join {shortname}_patient p on t.patientunitstayid=p.patientunitstayid           "
              "full join {shortname}_patientdeath d on p.patientunitstayid=d.patientunitstayid;".format(shortname=shortname),
              fetch=False, commit=True)

  # aggregate the time to events and event indicators
  db.do_query('drop table if exists {}_outs00;'.format(shortname), fetch=False, commit=True)
  db.do_query("create table {shortname}_outs00           "
              "as select patientunitstayid,           "
              "min(censor_or_deceased_days) as censor_or_deceased_days,           "
              "max(deceased_indicator) as deceased_indicator,           "
              "min(censor_or_vasopressor_days) as censor_or_vasopressor_days,           "
              "max(vasopressor_indicator) as vasopressor_indicator,           "
              "min(censor_or_ventilator_days) as censor_or_ventilator_days,           "
              "max(ventilator_indicator) as ventilator_indicator           "
              "from {shortname}_outs0           "
              "group by patientunitstayid;".format(shortname=shortname), fetch=False, commit=True)

  db.do_query('select count(*) from {}_outs00;'.format(shortname), fetch=True)
  db.do_query('select count(distinct(patientunitstayid)) from {}_outs00;'.format(shortname), fetch=True)

  db.do_query('update {}_outs00 set ventilator_indicator=0 where ventilator_indicator is null;'.format(shortname), fetch=False, commit=True)
  db.do_query('update {}_outs00 set vasopressor_indicator=0 where vasopressor_indicator is null;'.format(shortname), fetch=False, commit=True)

  # get the outcomes associated with first patient stays
  db.do_query('drop table if exists {}_outs;'.format(shortname), fetch=False, commit=True)
  db.do_query("create table {shortname}_outs as           "
              "select o.* from {shortname}_outs00 o           "
              "join {shortname}_firstpatientunitstayid p on p.patientunitstayid=o.patientunitstayid;".format(shortname=shortname), fetch=False, commit=True)
  db.do_query('select count(*) from {}_outs;'.format(shortname), fetch=True)
  db.do_query('select * from {}_outs limit(5);'.format(shortname), fetch=True)

  def create_out(d=1):
    """Compute the corresponding features and outcomes associated with the day. 
    (e.g. day 0 is 0 hours in, day 1 is 24 hours in, day 2 is 48 hours in, etc.)
    """
    lstr = -10000000000000000
    gstr = d * 24 * 60

    query = "select coalesce(f.patientunitstayid, o.patientunitstayid) as id, f.*,  " \
            "censor_or_deceased_days, " \
            "deceased_indicator,censor_or_vasopressor_days, " \
            "vasopressor_indicator,censor_or_ventilator_days, " \
            "ventilator_indicator " \
            "from (select * from {shortname}_features where t_offset > {lstr} and t_offset <= {gstr}) f             " \
            "inner join (select patientunitstayid, " \
            "           (censor_or_deceased_days-{day}) as censor_or_deceased_days, " \
            "           deceased_indicator,             " \
            "           (censor_or_vasopressor_days-{day}) as censor_or_vasopressor_days, vasopressor_indicator,    " \
            "           (censor_or_ventilator_days-{day}) as censor_or_ventilator_days, ventilator_indicator  " \
            "           from {shortname}_outs) o            " \
            "on f.patientunitstayid = o.patientunitstayid;".format(shortname=shortname, lstr=lstr, gstr=gstr, day=d)
    return query

  times = [0, 1, 2]
  pts = []
  for d in times:
    print('Creating csvs for day {}...'.format(d))
    print('before query')
    query = create_out(d)
    df = pd.read_sql(query, conn)
    print('df size:', df.shape)
    print('unique patientunitstayid:', len(df.id.unique()))

    cols = ['rbcs', 'wbc', 'platelets',
            'hemoglobin', 'hct', 'rdw', 'mcv', 'mch', 'mchc', 'neutrophils',
            'lymphocytes', 'monocytes', 'eosinophils', 'basophils', 'bun',
            'temperature', 'ph', 'sodium', 'glucose', 'pao2', 'fio2', 'ldh', 'crp',
            'direct_bilirubin', 'total_bilirubin', 'total_protein', 'albumin',
            'ferritin', 'pt', 'ptt', 'fibrinogen', 'ast', 'alt', 'creatinine',
            'troponin', 'alkaline_phosphatase', 'bands', 'bicarbonate', 'calcium',
            'chloride', 'potassium', 'gender', 'age', 'ethnicity',
            'heart_rate', 'sao2', 'gcs', 'respiratory_rate',
            'bp_systolic', 'bp_diastolic', 'bp_mean_arterial', 'smoking', 'pleural_effusion',
            'nursing_home', 'chest_xray', 
            'orientation', 'censor_or_deceased_days', 'deceased_indicator',
            'censor_or_vasopressor_days', 'vasopressor_indicator',
            'censor_or_ventilator_days', 'ventilator_indicator']
    pt = df
    pt.update(pt.groupby('id')[cols].ffill())
    pt = pt.groupby('id').last().reset_index()
    print('unique patientunitstayid:', len(pt.id.unique()))
    pt = pt[cols]
    fname = 'anypna'
    pt.to_csv('eicu_{}_{}_days_post_inicu.csv'.format(fname, d))
    print('saved csv for d{}'.format(d))
    print('pt size:', pt.shape)
  conn.close()


if __name__ == '__main__':
  main()
  