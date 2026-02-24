import 'package:flutter/material.dart';

const safetyTips = [
  "Never attempt to cross if water is above your tyres.",
  "Moving water is stronger than it looks — 6 inches can knock you down.",
  "Turn around, don't drown. Most flood deaths occur in vehicles.",
  "If swept away, exit the vehicle immediately and swim to safety.",
  "Flooded roads may have hidden damage or debris underneath.",
  "Avoid driving at night through unfamiliar flooded areas.",
  "Keep windows slightly open so you can escape if submerged.",
];

const emergencyContacts = [
  {'name': 'Bomba (Fire & Rescue)', 'number': '994',         'icon': Icons.local_fire_department_rounded, 'color': 0xFFFF3B30},
  {'name': 'Police',                'number': '999',         'icon': Icons.local_police_rounded,           'color': 0xFF5E9EFF},
  {'name': 'Ambulance',             'number': '999',         'icon': Icons.emergency_rounded,              'color': 0xFF00E676},
  {'name': 'Civil Defence (APM)',   'number': '03-86888888', 'icon': Icons.shield_rounded,                 'color': 0xFFFFD600},
  {'name': 'JKM (Welfare Dept)',    'number': '15999',       'icon': Icons.people_rounded,                 'color': 0xFFCF6DFF},
  {'name': 'Tenaga Nasional (TNB)', 'number': '15454',       'icon': Icons.bolt_rounded,                   'color': 0xFFFFAB40},
];

const floodAreas = [
  {'state': 'Kelantan',        'area': 'Kuala Krai, Gua Musang',    'risk': 'High'},
  {'state': 'Terengganu',      'area': 'Kuala Terengganu, Kemaman', 'risk': 'High'},
  {'state': 'Pahang',          'area': 'Temerloh, Kuantan',         'risk': 'High'},
  {'state': 'Johor',           'area': 'Kota Tinggi, Segamat',      'risk': 'High'},
  {'state': 'Perak',           'area': 'Sungai Perak Basin',        'risk': 'Medium'},
  {'state': 'Selangor',        'area': 'Shah Alam, Klang',          'risk': 'Medium'},
  {'state': 'Sabah',           'area': 'Tawau, Keningau',           'risk': 'Medium'},
  {'state': 'Sarawak',         'area': 'Kapit, Sri Aman',           'risk': 'Medium'},
  {'state': 'Kedah',           'area': 'Pendang, Baling',           'risk': 'Low'},
  {'state': 'Negeri Sembilan', 'area': 'Kuala Pilah',               'risk': 'Low'},
];