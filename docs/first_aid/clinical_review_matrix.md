# ResQMe First Aid — Source-Fidelity Audit & Clinical Review Matrix

> **PUBLIC RELEASE BLOCKER NOTICE:** Every topic in `assets/data/first_aid_library.json` has undergone deterministic page-level verification against the official *IFRC International First Aid, Resuscitation and Education Guidelines 2025* (`SHA-256: EED67BDFF38CA8A7628C7B01BE5BCD23796601E0D85BB021DC301EC3F9FF8F1F`), so `sourceVerification` is `verified`. However, **human clinical sign-off by a qualified medical reviewer has NOT yet occurred** (`clinicalApproval: "pending"`, `reviewer: null`, `approvedAt: null`). `FirstAidReleasePolicy.publicRelease` strictly blocks unapproved topics from appearing in public release builds until signed clinical approval is recorded.

---

## 1. High-Risk Procedure Source-Fidelity Audit

| Priority Domain | Representative Topic ID | Source-Fidelity Audit Result (`IFRC 2025`) | Audit Status |
|---|---|---|---|
| **CPR (Adult, Child & Infant)** | `cpr-adult` | Verified 30:2 compression-to-breath ratio, 100–120/min rate, 5–6 cm adult depth, ~5 cm child depth (5 initial rescue breaths for trained responders), ~4 cm two-finger/two-thumb infant depth, compression-only fallback for untrained/unwilling responders, and firm flat surface (pp. 159–198). | `PASS (Source Verified)` |
| **Choking (Adult, Child & Infant)** | `choking-adult` | Verified effective cough encouragement first; 5 back blows + 5 abdominal thrusts for adults/children >1 yr (chest thrusts if pregnant/obese); 5 back blows + 5 two-finger chest thrusts (NO abdominal thrusts, NO blind finger sweeps) for infants <1 yr (pp. 238–244). | `PASS (Source Verified)` |
| **Drowning** | `drowning` | Verified water-rescue safety ('reach/throw, don't go'), trained oxygenation priority (5 initial rescue breaths before 30:2 CPR), NO abdominal thrusts to clear water, and mandatory hospital assessment after submersion (pp. 215–229). | `PASS (Source Verified)` |
| **Severe Bleeding** | `severe-bleeding` | Verified immediate direct manual pressure, second dressing on top if soaked through, NO embedded object removal, NO indirect pressure points, and manufactured windlass tourniquet (5–7 cm above limb wound, never over a joint, never loosened) or haemostatic dressing packing when direct pressure fails (pp. 256–266). | `PASS (Source Verified)` |
| **Unconscious Patients (Normal Breathing)** | `unresponsive-normal-breathing` | Verified head-tilt/chin-lift airway check (neutral in infants), <=10 s breathing check (recognizing agonal gasps as cardiac arrest), recovery position when breathing normally without spinal suspicion, left-lateral tilt in late pregnancy, and continuous breathing monitoring (pp. 152–158). | `PASS (Source Verified)` |
| **Anaphylaxis** | `anaphylaxis` | Verified immediate intramuscular epinephrine autoinjector into outer mid-thigh, Call 911, supine posture (or upright if breathless—NEVER standing/walking), repeat epinephrine at 5–10 min if no improvement, and mandatory hospital observation for biphasic reaction risk (pp. 376–387). | `PASS (Source Verified)` |
| **Poisoning** | `poisoning` | Verified poison control / 911 call with container details, NO induced vomiting (especially caustics/petroleum), NO routine milk/water/unsupervised activated charcoal, fresh-air evacuation for CO/fumes, and 15–20 min water irrigation for skin/eye exposure (pp. 346–353). | `PASS (Source Verified)` |
| **Heatstroke** | `heatstroke` | Verified 'cool first, transport second' priority: immediate neck-down cold-water immersion (1–26 °C) until <39 °C or mental status clears (or cold dousing + wet sheets + fanning + neck/armpit/groin ice packs), NO antipyretics (paracetamol/NSAIDs), and NO oral fluids when confused/drowsy (pp. 446–453). | `PASS (Source Verified)` |
| **Hypoglycemia** | `hypoglycemia` | Verified 15–20 g oral fast-acting glucose (tablets preferred, or 3 tsp sugar/juice/regular sweets) ONLY if awake and able to swallow, 15-min re-check and repeat dose, treat as low blood sugar if unsure between hypo/hyperglycaemia, NEVER give oral items if drowsy/unresponsive, and NEVER give insulin (pp. 391–395). | `PASS (Source Verified)` |
| **Mental Health Emergencies (PFA, Trauma, Suicide, Grief, Panic)** | `suicidal-ideation` | Verified Look–Listen–Link, NO single-session trauma debriefing, NEVER leaving imminent-suicide-risk persons alone, safe lethal-means removal, transparent safety limits on confidentiality, non-stigmatizing language, and slow 1:3 abdominal breathing WITHOUT paper-bag rebreathing for panic attacks (pp. 129–134, 486–521). | `PASS (Source Verified)` |

---

## 2. Clinical Review Matrix (All 66 Canonical Procedures)

| # | Topic ID | Topic Title | Category | Source Pages (IFRC 2025) | Audience | Source Verification | Clinical Approval | Reviewer | Approved At | Release Gate Status |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `initial-assessment` | Initial Assessment (Primary Survey) | General Emergency Response | pp. 114–128 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 2 | `scene-safety` | Scene Safety & Emergency Response | General Emergency Response | pp. 114–128 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 3 | `psychological-first-aid` | Psychological First Aid (Look, Listen, Link) | General Emergency Response | pp. 129–135 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 4 | `hand-hygiene` | Hand Hygiene & Infection Protection | General Emergency Response | pp. 136–140 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 5 | `oxygen-administration` | Oxygen Administration (Trained Responders Only) | General Emergency Response | pp. 141–149 | `trained_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 6 | `unresponsive-normal-breathing` | Unresponsive Person Breathing Normally (Recovery Position) | Resuscitation & Life-Saving | pp. 152–158 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 7 | `cpr-adult` | Adult and Adolescent CPR | Resuscitation & Life-Saving | pp. 159–185 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 8 | `cpr-child` | Child CPR (1 Year to Puberty) | Resuscitation & Life-Saving | pp. 186–195 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 9 | `cpr-infant` | Infant CPR (Under 1 Year) | Resuscitation & Life-Saving | pp. 186–195 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 10 | `aed-use` | AED (Automated External Defibrillator) Use | Resuscitation & Life-Saving | pp. 196–207 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 11 | `opioid-overdose` | Suspected Opioid Overdose | Resuscitation & Life-Saving | pp. 208–214 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 12 | `drowning` | Drowning | Resuscitation & Life-Saving | pp. 215–229 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 13 | `breathing-difficulties` | Breathing Difficulties (Including Hyperventilation) | Breathing Emergencies | pp. 232–237 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 14 | `choking-adult` | Adult Choking | Breathing Emergencies | pp. 238–244 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 15 | `choking-child` | Child Choking (1 Year and Older) | Breathing Emergencies | pp. 238–244 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 16 | `choking-infant` | Infant Choking (Under 1 Year) | Breathing Emergencies | pp. 238–244 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 17 | `asthma-attack` | Asthma Attack | Breathing Emergencies | pp. 245–249 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 18 | `croup` | Croup | Breathing Emergencies | pp. 250–253 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 19 | `severe-bleeding` | Severe Bleeding | Trauma & Injuries | pp. 256–266 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 20 | `chest-abdomen-injuries` | Chest and Abdominal Injuries | Trauma & Injuries | pp. 267–270 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 21 | `amputation` | Amputation | Trauma & Injuries | pp. 271–274 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 22 | `cuts-and-grazes` | Cuts and Grazes | Trauma & Injuries | pp. 275–279 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 23 | `knocked-out-teeth` | Knocked-Out Tooth (Dental Avulsion) | Trauma & Injuries | pp. 280–282 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 24 | `friction-blisters` | Blisters (Friction Blisters) | Trauma & Injuries | pp. 283–287 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 25 | `burns` | Burns (Thermal, Electrical & Sunburn) | Trauma & Injuries | pp. 288–298 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 26 | `chemical-burns` | Chemical Burns (Skin & Eye) | Trauma & Injuries | pp. 288–298 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 27 | `flash-eye` | Flash Eye (Arc Eye / Snow Blindness) | Trauma & Injuries | pp. 299–300 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 28 | `fractures` | Fractures (Broken Bones & Dislocations) | Trauma & Injuries | pp. 301–306 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 29 | `sprains` | Sprains (Joint Ligament Injuries) | Trauma & Injuries | pp. 301–306 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 30 | `strains` | Strains (Muscle & Tendon Injuries) | Trauma & Injuries | pp. 301–306 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 31 | `spinal-injury` | Spinal Injuries (Neck, Back & Pelvic Trauma) | Trauma & Injuries | pp. 307–311 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 32 | `head-injury-concussion` | Head Injuries and Concussion | Trauma & Injuries | pp. 312–317 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 33 | `lower-back-pain` | Acute Lower Back Pain | Trauma & Injuries | pp. 318–322 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 34 | `mammal-bites` | Mammal Bites (Dog, Cat, Human & Animal Bites) | Trauma & Injuries | pp. 323–325 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 35 | `insect-bites-stings` | Insect Bites and Stings (Including Ticks) | Trauma & Injuries | pp. 326–333 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 36 | `aquatic-animal-injuries` | Aquatic Animal Injuries (Jellyfish, Stingray & Sea Urchin) | Trauma & Injuries | pp. 334–339 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 37 | `snakebites` | Snakebites | Trauma & Injuries | pp. 340–345 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 38 | `poisoning` | Poisoning (Swallowed, Inhaled, Skin & Button Batteries) | Trauma & Injuries | pp. 346–353 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 39 | `nosebleeds` | Nosebleeds | Trauma & Injuries | pp. 354–356 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 40 | `cardiac-chest-pain` | Cardiac Chest Pain (Suspected Heart Attack) | Medical Emergencies | pp. 358–365 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 41 | `stroke` | Stroke (FAST Assessment) | Medical Emergencies | pp. 366–375 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 42 | `anaphylaxis` | Anaphylaxis (Severe Allergic Reaction) | Medical Emergencies | pp. 376–387 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 43 | `allergic-reaction-mild` | Mild to Moderate Allergic Reaction | Medical Emergencies | pp. 376–387 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 44 | `shock` | Circulatory Shock | Medical Emergencies | pp. 388–390 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 45 | `hypoglycemia` | Hypoglycemia (Low Blood Sugar / Diabetic Emergency) | Medical Emergencies | pp. 391–395 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 46 | `seizures` | Seizures and Convulsions (Including Febrile Seizures) | Medical Emergencies | pp. 396–400 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 47 | `feeling-faint` | Feeling Faint and Fainting (Syncope) | Medical Emergencies | pp. 401–405 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 48 | `fever` | Fever | Medical Emergencies | pp. 406–411 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 49 | `abdominal-pain` | Abdominal Pain (Non-Traumatic) | Medical Emergencies | pp. 412–417 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 50 | `emergency-childbirth` | Emergency Childbirth | Medical Emergencies | pp. 418–427 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 51 | `sore-throat` | Sore Throat | Medical Emergencies | pp. 428–432 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 52 | `earache` | Earache and Foreign Object in the Ear | Medical Emergencies | pp. 433–435 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 53 | `headache` | Headache and Migraine | Medical Emergencies | pp. 436–440 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 54 | `hiccups` | Hiccups | Medical Emergencies | pp. 441–443 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 55 | `heatstroke` | Heatstroke (Life-Threatening Hyperthermia) | Environmental Emergencies | pp. 446–453 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 56 | `heat-exhaustion` | Heat Exhaustion and Heat Cramps | Environmental Emergencies | pp. 446–453 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 57 | `dehydration` | Dehydration and Oral Rehydration (ORS) | Environmental Emergencies | pp. 454–460 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 58 | `hypothermia` | Hypothermia (Dangerously Low Body Temperature) | Environmental Emergencies | pp. 461–466 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 59 | `frostbite` | Frostbite and Cold Skin Injury | Environmental Emergencies | pp. 467–469 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 60 | `altitude-sickness` | Altitude Sickness (AMS, HAPE & HACE) | Environmental Emergencies | pp. 470–474 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 61 | `decompression-illness` | Decompression Illness (Diving Emergencies — Trained Oxygen Protocol) | Environmental Emergencies | pp. 475–478 | `trained_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 62 | `motion-sickness` | Motion Sickness (Car, Sea & Air Sickness) | Environmental Emergencies | pp. 479–483 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 63 | `traumatic-event` | Distress After a Traumatic Event | Mental Distress | pp. 486–493 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 64 | `suicidal-ideation` | Suicidal Ideation and Self-Harm Crisis | Mental Distress | pp. 494–502 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 65 | `acute-grief` | Acute Grief and Sudden Loss | Mental Distress | pp. 503–514 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |
| 66 | `anxiety-and-panic` | Acute Anxiety and Panic Attack | Mental Distress | pp. 515–521 | `lay_responder` | `verified` | `PENDING` | `None` | `None` | `BLOCKED FOR PUBLIC RELEASE` |

---

## 3. Clinical Sign-Off Procedure for Qualified Medical Reviewers

1. Inspect each procedure in `assets/data/first_aid_library.json` alongside the cited printed/PDF pages of *IFRC International First Aid, Resuscitation and Education Guidelines 2025*.
2. Verify local Philippine emergency protocol alignment (National Emergency Hotline `911`, Philippine Red Cross `143`, NCMH Crisis Hotline `1553`, and local medication administration regulations).
3. Record only genuine, signed human review credentials in `review.reviewer`, `review.reviewerQualification`, `review.approvedAt` (ISO-8601 date), and set `review.clinicalApproval` to `"approved"` per approved topic.
4. Re-run `flutter test test/features/public_support/first_aid_content_integrity_test.dart` to validate schema and release-gate integrity.
