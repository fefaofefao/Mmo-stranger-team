#!/usr/bin/env python3
"""Gerador inicial dos dados de balanceamento (JSON em data/).

ATENCAO: os arquivos JSON em data/ sao a fonte da verdade do jogo. Este script
serve para (re)criar o conteudo base. Se voce ajustar os JSON na mao e rodar o
script de novo, os ajustes serao sobrescritos (exceto data/config.json e
data/ads.json, que este script nunca toca).

Uso:  python3 tools/gen_data.py
"""
import json
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

TYPES = [
    ("agua", "Água", "#3b7fd9"),
    ("fogo", "Fogo", "#e0522b"),
    ("gelo", "Gelo", "#7fd6e8"),
    ("planta", "Planta", "#4caf3f"),
    ("terra", "Terra", "#a8743a"),
    ("eletrico", "Elétrico", "#f2d023"),
    ("vento", "Vento", "#b9c9d6"),
    ("luz", "Luz", "#fff1a8"),
    ("sombra", "Sombra", "#6a3d9a"),
]
TYPE_IDS = [t[0] for t in TYPES]

# (nomes dos 3 estagios, formato, estilo, conceito)
FAMILIES = {
    "agua": [
        (["Gotelo", "Gotalume", "Marevolto"], "blob", "magic", "uma gota de água viva que brilha quando está feliz", True),
        (["Escamim", "Escamarco", "Abissarpão"], "fish", "melee", "um peixinho de escamas duras que morde tudo que se mexe", False),
        (["Enguilha", "Enguirreal", "Leviaguar"], "serpent", "ranged", "uma enguia que dispara jatos de água pressurizada", False),
        (["Lontrel", "Lontrávio", "Correntauro"], "quadruped", "melee", "uma lontra brincalhona que nada contra qualquer correnteza", False),
        (["Siricó", "Siriguerra", "Carapaçal"], "insect", "melee", "um siri de pinças afiadas que vive entre os corais", False),
    ],
    "fogo": [
        (["Brasito", "Brasalobo", "Infernauro"], "quadruped", "melee", "um filhote de lobo com brasas no lugar do pelo", True),
        (["Faísco", "Fagulhavo", "Fenígneo"], "bird", "ranged", "um passarinho que solta faíscas ao bater as asas", False),
        (["Lavinha", "Lavorbe", "Magmastro"], "blob", "magic", "uma bolha de lava que borbulha quando pensa", False),
        (["Cinzobra", "Cinzerpe", "Vulcanaga"], "serpent", "melee", "uma cobra de cinzas quentes que deixa trilhas fumegantes", False),
        (["Carvãozinho", "Carvoluto", "Fornalhão"], "golem", "melee", "um pedaço de carvão que ganhou vida dentro de um vulcão", False),
    ],
    "gelo": [
        (["Flocote", "Flocário", "Nevascor"], "bird", "ranged", "uma ave de penas de neve que atira flocos cortantes", True),
        (["Geladim", "Gelopardo", "Glaciafera"], "quadruped", "melee", "um felino de pelagem congelada e passos silenciosos", False),
        (["Brumito", "Brumálgido", "Aurorgelo"], "spirit", "magic", "um espírito de névoa gelada que canta ao amanhecer", False),
        (["Cristelo", "Cristalurso", "Permagelo"], "golem", "melee", "um ursinho de cristal de gelo, pesado e teimoso", False),
        (["Focuxo", "Focalante", "Morsagelo"], "fish", "ranged", "uma foca que cospe bolas de gelo com precisão", False),
    ],
    "planta": [
        (["Brotim", "Ramagueiro", "Silvatronco"], "biped", "melee", "um broto que aprendeu a andar e a dar cabeçadas", True),
        (["Joaninho", "Besourama", "Escaravelva"], "insect", "ranged", "um besouro que lança sementes como projéteis", False),
        (["Musguinho", "Musgolento", "Fungimor"], "blob", "magic", "um tufo de musgo que solta esporos sonolentos", False),
        (["Cipolim", "Cipovenha", "Lianaconda"], "serpent", "melee", "um cipó vivo que se enrola nos inimigos", False),
        (["Pétalim", "Floricolibri", "Orquidália"], "bird", "ranged", "um beija-flor feito de pétalas e pólen", False),
    ],
    "terra": [
        (["Seixinho", "Pedregão", "Monolitauro"], "golem", "melee", "uma pedrinha teimosa que nunca recua", True),
        (["Toupeirim", "Cavadouro", "Escavassauro"], "quadruped", "melee", "uma toupeira que cava túneis em segundos", False),
        (["Formigal", "Formigarra", "Cupinzarca"], "insect", "ranged", "uma formiga que arremessa grãos de areia endurecida", False),
        (["Grãozinho", "Areiaga", "Dunaserpe"], "serpent", "magic", "uma serpente de areia que comanda pequenos redemoinhos", False),
        (["Lamacim", "Barrolem", "Argilossauro"], "biped", "melee", "um bonequinho de barro moldado pela chuva", False),
    ],
    "eletrico": [
        (["Choquito", "Voltífera", "Trovajante"], "quadruped", "ranged", "um bichinho de pelo arrepiado que dispara choques", True),
        (["Pardalume", "Raioave", "Trovoréu"], "bird", "magic", "um pardal que atrai relâmpagos com o canto", False),
        (["Vespeta", "Vespacorrente", "Zumbitrão"], "insect", "melee", "uma vespa elétrica de ferrão faiscante", False),
        (["Enguitilo", "Amperaia", "Tesloraia"], "fish", "ranged", "uma raia que acumula estática nas nadadeiras", False),
        (["Pilhote", "Bobinardo", "Dínamorgo"], "golem", "magic", "uma pilha antiga que despertou com um raio", False),
    ],
    "vento": [
        (["Plumito", "Brisavo", "Furacondor"], "bird", "ranged", "um filhote de ave que vive pegando carona nas brisas", True),
        (["Sopradinho", "Redemoinhal", "Ciclonarca"], "spirit", "magic", "um pequeno redemoinho com olhos curiosos", False),
        (["Libelim", "Libelâmina", "Ceifavento"], "insect", "melee", "uma libélula de asas afiadas como lâminas", False),
        (["Lebrisco", "Corrisopro", "Galerauro"], "quadruped", "melee", "uma lebre tão rápida que deixa rastros de vento", False),
        (["Nuvélio", "Nimbosserpe", "Dragonimbo"], "serpent", "ranged", "uma serpente de nuvem que dispara rajadas de ar", False),
    ],
    "luz": [
        (["Lumito", "Lumiário", "Auréolux"], "spirit", "magic", "uma pequena chama de luz pura que espanta pesadelos", True),
        (["Pombrilho", "Resplume", "Solárion"], "bird", "ranged", "uma pomba de penas reluzentes que dispara raios de sol", False),
        (["Prismito", "Prismalião", "Vitralossus"], "golem", "melee", "um cristal prismático que decompõe a luz em golpes", False),
        (["Potrilume", "Corcelux", "Alvorcorno"], "quadruped", "melee", "um potro de crina luminosa que galopa ao nascer do sol", False),
        (["Cintilim", "Cintilóide", "Supernovo"], "blob", "magic", "uma bolinha de luz estelar que pulsa como uma estrela", False),
    ],
    "sombra": [
        (["Breuzinho", "Breulobo", "Eclipsauro"], "quadruped", "melee", "um filhote feito de breu que só aparece à noite", True),
        (["Assombrim", "Espectrélio", "Penumbrarca"], "spirit", "magic", "um fantasminha tímido que sussurra maldições", False),
        (["Corvito", "Corvoturvo", "Nocturnave"], "bird", "ranged", "um corvo de olhos vermelhos que arremessa penas sombrias", False),
        (["Aranhoca", "Tecelúgubre", "Viúvanoite"], "insect", "melee", "uma aranha que tece teias de escuridão", False),
        (["Vultinho", "Vultoserpe", "Abismorgo"], "serpent", "magic", "uma serpente de vulto que surge das sombras", False),
    ],
}

STAGE_NAMES = ["Filhote", "Adolescente", "Adulto"]
STAGE_DESC = [
    "Filhote: {c}.",
    "Adolescente: mais forte e confiante, {c2}.",
    "Adulto: forma plena e temida, {c3}.",
]
STAGE_EXTRA2 = {
    "melee": "agora parte para o corpo a corpo sem hesitar",
    "ranged": "acerta alvos distantes com facilidade",
    "magic": "domina feitiços de área",
}
STAGE_EXTRA3 = {
    "melee": "capaz de derrubar grupos inteiros em combate próximo",
    "ranged": "um atirador implacável de longo alcance",
    "magic": "sua magia transforma o campo de batalha",
}

# Nome das habilidades por tipo: strike, bolt, burst, blast, heal, dot, ult
ABILITY_NAMES = {
    "agua": ["Pancada de Maré", "Jato d'Água", "Onda Circular", "Bomba de Bolhas", "Névoa Restauradora", "Correnteza", "Tsunami"],
    "fogo": ["Garra Flamejante", "Bola de Fogo", "Explosão de Brasas", "Chuva de Lava", "Calor Vital", "Queimadura", "Erupção"],
    "gelo": ["Mordida Gélida", "Estilhaço de Gelo", "Anel de Geada", "Granizo", "Casulo de Gelo", "Congelamento", "Nevasca"],
    "planta": ["Chicote de Vinha", "Semente Bala", "Espinhos Ao Redor", "Explosão de Pólen", "Fotossíntese", "Esporos Tóxicos", "Fúria da Floresta"],
    "terra": ["Pancada Rochosa", "Arremesso de Pedra", "Tremor", "Desabamento", "Pele de Pedra", "Areia Movediça", "Terremoto"],
    "eletrico": ["Ferrão Voltaico", "Faísca", "Descarga", "Raio Concentrado", "Recarga", "Estática", "Tempestade de Raios"],
    "vento": ["Corte de Ar", "Rajada", "Redemoinho", "Lâminas de Vento", "Brisa Curativa", "Vendaval", "Furacão"],
    "luz": ["Golpe Radiante", "Raio de Sol", "Clarão", "Coluna de Luz", "Bênção", "Ofuscar", "Juízo Solar"],
    "sombra": ["Mordida Sombria", "Projétil Umbral", "Onda de Breu", "Abismo", "Drenar Vida", "Maldição", "Eclipse Total"],
}
ABILITY_KINDS = ["strike", "bolt", "burst", "blast", "heal", "dot", "ult"]
ABILITY_TEMPLATE = {
    # power = multiplicador do ataque; radius em tiles; range em tiles; cd em segundos
    "strike": {"target": "enemy", "power": 1.9, "radius": 0, "range": 1, "cooldown": 6.0, "fx": "slash"},
    "bolt": {"target": "enemy", "power": 1.7, "radius": 0, "range": 5, "cooldown": 5.0, "fx": "projectile"},
    "burst": {"target": "self_area", "power": 1.3, "radius": 1, "range": 0, "cooldown": 8.0, "fx": "ring"},
    "blast": {"target": "enemy_area", "power": 1.4, "radius": 1, "range": 5, "cooldown": 8.0, "fx": "explosion"},
    "heal": {"target": "self", "power": 0.25, "radius": 0, "range": 0, "cooldown": 14.0, "fx": "heal"},
    "dot": {"target": "enemy_area", "power": 0.5, "radius": 1, "range": 5, "cooldown": 10.0, "fx": "rain", "ticks": 4},
    "ult": {"target": "self_area", "power": 2.4, "radius": 2, "range": 0, "cooldown": 16.0, "fx": "nova"},
}
STYLE_ABILITIES = {
    "melee": [["strike"], ["strike", "burst"], ["burst", "ult"]],
    "ranged": [["bolt"], ["bolt", "blast"], ["blast", "ult"]],
    "magic": [["blast"], ["blast", "heal"], ["dot", "ult"]],
}

STYLE_BASE = {
    "melee": {"hp": 60, "atk": 12, "def": 10, "spd": 100, "rng": 1},
    "ranged": {"hp": 50, "atk": 12, "def": 8, "spd": 104, "rng": 4},
    "magic": {"hp": 46, "atk": 13.5, "def": 7.5, "spd": 96, "rng": 3},
}
SHAPE_MOD = {
    "blob": {"hp": 1.05, "def": 1.0, "spd": 0.95},
    "quadruped": {"hp": 1.0, "atk": 1.05, "spd": 1.06},
    "bird": {"hp": 0.92, "spd": 1.1},
    "serpent": {"atk": 1.04, "def": 0.97},
    "biped": {"hp": 1.03, "def": 1.03},
    "insect": {"atk": 1.06, "hp": 0.95},
    "fish": {"hp": 1.02, "spd": 1.02},
    "golem": {"hp": 1.12, "def": 1.15, "spd": 0.86},
    "spirit": {"atk": 1.06, "hp": 0.92, "spd": 1.04},
}

BIOMES = [
    # id, nome, tipos, estilo de geracao, wall_style, deco_style, paleta
    ("praia", "Praia", ["agua"], "islands", "water", "shell", ["#e8d9a0", "#dfcf92", "#efe2ae"], "#2f6fb5", ["#f4f0e0", "#d98c6a"]),
    ("lago", "Lago", ["agua"], "islands", "water", "grass", ["#6aa84f", "#5f9a46", "#76b55a"], "#2a5f9e", ["#9fd18a", "#e9e27a"]),
    ("recife", "Recife", ["agua"], "cave", "coral", "shell", ["#3f8fae", "#378299", "#4a9cbb"], "#c2566f", ["#f2a9b8", "#9be0e8"]),
    ("vulcao", "Vulcão", ["fogo"], "cave", "rock", "ember", ["#4a3a34", "#41332e", "#55443d"], "#2a1e1b", ["#ff7a2a", "#ffd04a"]),
    ("campo_lava", "Campo de Lava", ["fogo"], "islands", "lava", "ember", ["#5b4036", "#523a31", "#66493e"], "#e04a1a", ["#ffb03a", "#3a2a24"]),
    ("tundra", "Tundra", ["gelo"], "open", "ice", "snow", ["#e6f0f5", "#dbe8ef", "#f0f6f9"], "#8fbcd4", ["#ffffff", "#b5d7e6"]),
    ("caverna_congelada", "Caverna Congelada", ["gelo"], "cave", "ice", "crystal", ["#a9c9da", "#9dbfd1", "#b6d3e2"], "#5d8aa8", ["#e8fbff", "#7fd6e8"]),
    ("campo_grama", "Campo de Grama", ["planta"], "open", "tree", "flower", ["#5fa843", "#569c3c", "#68b34b"], "#2e6b23", ["#f5e050", "#e86a8a"]),
    ("floresta_densa", "Floresta Densa", ["planta"], "cave", "tree", "mushroom", ["#3f7d33", "#38722d", "#47883a"], "#1f4a1a", ["#d94a3a", "#c9e07a"]),
    ("canion", "Cânion", ["terra"], "open", "rock", "pebble", ["#c98a52", "#bd7f49", "#d4955c"], "#7a4a28", ["#8a5a35", "#e0b07a"]),
    ("caverna_rochosa", "Caverna Rochosa", ["terra"], "cave", "rock", "pebble", ["#7b6a5a", "#706050", "#857463"], "#3d332a", ["#a89880", "#5a4a3a"]),
    ("planalto_tempestade", "Planalto da Tempestade", ["eletrico"], "open", "rock", "spark", ["#5d6b4a", "#536042", "#677553"], "#2f3528", ["#f2d023", "#a8e0ff"]),
    ("ruinas_energizadas", "Ruínas Energizadas", ["eletrico"], "rooms", "pillar", "spark", ["#6a6a7a", "#60606f", "#747485"], "#3a3a48", ["#f2d023", "#7af0ff"]),
    ("picos", "Picos Montanhosos", ["vento"], "open", "rock", "feather", ["#9aa59a", "#8f9a8f", "#a5b0a5"], "#5a625a", ["#ffffff", "#c9d6e0"]),
    ("plataformas_nuvens", "Plataformas nas Nuvens", ["vento"], "islands", "cloud", "feather", ["#e9eef5", "#dfe6ef", "#f2f5fa"], "#9fc3e8", ["#ffffff", "#ffe9a8"]),
    ("templo", "Templo", ["luz"], "rooms", "pillar", "crystal", ["#e8dcc0", "#ddd0b2", "#f0e6cc"], "#a89060", ["#fff1a8", "#ffffff"]),
    ("campo_cristais", "Campo de Cristais", ["luz"], "open", "crystal", "crystal", ["#d8e6c8", "#cddcbc", "#e2efd3"], "#f0e080", ["#fff8c8", "#bff0ff"]),
    ("floresta_sombria", "Floresta Sombria", ["sombra"], "cave", "tree", "mushroom", ["#2f3a2c", "#293326", "#354232"], "#121a12", ["#8a5ad0", "#4a6a3a"]),
    ("cemiterio", "Cemitério Antigo", ["sombra"], "rooms", "tomb", "bone", ["#4a4a40", "#424238", "#535348"], "#2a2a28", ["#d8d8c8", "#6a3d9a"]),
    # biomas de transicao
    ("pantano", "Pântano", ["agua", "planta"], "islands", "water", "mushroom", ["#5a6e3a", "#526534", "#627844"], "#2f4a3a", ["#9ab04a", "#c9a0d0"]),
    ("fontes_termais", "Fontes Termais", ["agua", "fogo"], "islands", "water", "ember", ["#8a7a6a", "#807060", "#958575"], "#4aa0b0", ["#ffffff", "#ff9a5a"]),
    ("deserto_cinzas", "Deserto de Cinzas", ["fogo", "terra"], "open", "rock", "ember", ["#8a7060", "#806656", "#957a6a"], "#4a3a30", ["#ff7a2a", "#c0a080"]),
    ("geleira_rochosa", "Geleira Rochosa", ["gelo", "terra"], "cave", "ice", "pebble", ["#b8c4c8", "#adb9bd", "#c3cfd3"], "#6a7a80", ["#ffffff", "#8a7a6a"]),
    ("cordilheira_ventosa", "Cordilheira Ventosa", ["vento", "terra", "eletrico"], "open", "rock", "feather", ["#8a9a8a", "#809080", "#95a595"], "#4a5a4a", ["#f2d023", "#ffffff"]),
    ("crepusculo", "Vale do Crepúsculo", ["luz", "sombra"], "rooms", "pillar", "crystal", ["#7a6a8a", "#706080", "#857595"], "#3a2a4a", ["#fff1a8", "#6a3d9a"]),
    ("brejo_sombrio", "Brejo Sombrio", ["sombra", "planta"], "cave", "tree", "mushroom", ["#3a4a30", "#33422a", "#425236"], "#1a221a", ["#8a5ad0", "#9ab04a"]),
    ("geleira_eterea", "Geleira Etérea", ["gelo", "vento"], "open", "ice", "feather", ["#dce8f0", "#d0dee8", "#e6f0f6"], "#8fbcd4", ["#ffffff", "#c9d6e0"]),
    ("tempestade_luminosa", "Tempestade Luminosa", ["eletrico", "luz"], "open", "crystal", "spark", ["#c8c890", "#bebe86", "#d2d29a"], "#8a8a40", ["#f2d023", "#ffffff"]),
]

PLACE_ADJ = ["Serena", "Antiga", "Perdida", "Sussurrante", "Dourada", "Silenciosa", "Selvagem", "Profunda", "Esquecida",
             "Brilhante", "Tranquila", "Ventosa", "Sombria", "Encantada", "Escondida", "Bravia", "Eterna", "Rasa",
             "Distante", "Rubra", "Azulada", "Velha", "Nova", "Alta", "Baixa", "Torta", "Larga", "Estreita"]
PLACE_NOUN = {
    "praia": ["Enseada", "Costa", "Baía"], "lago": ["Lagoa", "Margem", "Açude"], "recife": ["Recife", "Atol", "Banco de Coral"],
    "vulcao": ["Cratera", "Encosta", "Chaminé"], "campo_lava": ["Planície", "Fenda", "Escarpa"],
    "tundra": ["Estepe", "Planície", "Campina"], "caverna_congelada": ["Gruta", "Caverna", "Galeria"],
    "campo_grama": ["Pradaria", "Campina", "Colina"], "floresta_densa": ["Mata", "Floresta", "Clareira"],
    "canion": ["Desfiladeiro", "Garganta", "Ravina"], "caverna_rochosa": ["Mina", "Caverna", "Toca"],
    "planalto_tempestade": ["Chapada", "Planalto", "Meseta"], "ruinas_energizadas": ["Ruína", "Usina", "Cidadela"],
    "picos": ["Pico", "Serra", "Crista"], "plataformas_nuvens": ["Ilha Celeste", "Plataforma", "Ninho"],
    "templo": ["Santuário", "Templo", "Capela"], "campo_cristais": ["Jazida", "Campo", "Vale"],
    "floresta_sombria": ["Floresta", "Bosque", "Mata"], "cemiterio": ["Necrópole", "Cripta", "Campo-Santo"],
    "pantano": ["Brejo", "Charco", "Pântano"], "fontes_termais": ["Fonte", "Nascente", "Gêiser"],
    "deserto_cinzas": ["Deserto", "Ermo", "Planície"], "geleira_rochosa": ["Geleira", "Morena", "Fiorde"],
    "cordilheira_ventosa": ["Cordilheira", "Passo", "Desfiladeiro"], "crepusculo": ["Vale", "Pátio", "Claustro"],
    "brejo_sombrio": ["Brejo", "Lodaçal", "Charco"], "geleira_eterea": ["Geleira", "Campo", "Cume"],
    "tempestade_luminosa": ["Planalto", "Campo", "Chapada"],
}

SLOTS = [
    ("amuleto", "Amuleto", "hp", ["Pingente", "Amuleto", "Medalhão", "Talismã", "Colar", "Gargantilha", "Insígnia", "Relicário", "Coroa-Pingente"]),
    ("garra", "Garra", "atk", ["Garra", "Presa", "Ferrão", "Lâmina", "Gadanha", "Navalha", "Dente-Rei", "Ceifadora", "Garra Ancestral"]),
    ("armadura", "Armadura", "def", ["Couraça", "Escama", "Carapaça", "Malha", "Égide", "Coura", "Bastião", "Fortaleza", "Manto Primevo"]),
    ("reliquia", "Relíquia", "spd", ["Seixo", "Orbe", "Totem", "Ídolo", "Cristal", "Fragmento", "Núcleo", "Coração", "Essência Viva"]),
]
TYPE_ADJ = {"agua": "Coralino", "fogo": "Ígneo", "gelo": "Glacial", "planta": "Silvestre", "terra": "Rochoso",
            "eletrico": "Voltaico", "vento": "Etéreo", "luz": "Radiante", "sombra": "Umbral"}
TYPE_ADJ_F = {"agua": "Coralina", "fogo": "Ígnea", "gelo": "Glacial", "planta": "Silvestre", "terra": "Rochosa",
              "eletrico": "Voltaica", "vento": "Etérea", "luz": "Radiante", "sombra": "Umbral"}
FEMININE = {"Couraça", "Escama", "Carapaça", "Malha", "Égide", "Coura", "Fortaleza", "Presa", "Lâmina", "Gadanha",
            "Navalha", "Ceifadora", "Garra", "Garra Ancestral", "Insígnia", "Gargantilha", "Coroa-Pingente", "Essência Viva"}
TIERS = [
    {"tier": 1, "level": 1, "world2": False},
    {"tier": 2, "level": 12, "world2": False},
    {"tier": 3, "level": 25, "world2": False},
    {"tier": 4, "level": 40, "world2": False},
    {"tier": 5, "level": 60, "world2": False},
    {"tier": 6, "level": 80, "world2": False},
    {"tier": 7, "level": 120, "world2": True},
    {"tier": 8, "level": 170, "world2": True},
    {"tier": 9, "level": 230, "world2": True},
]


def wjson(name, obj):
    path = os.path.join(DATA, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    print("escrito", path)


def gen_types():
    wjson("types.json", {
        "_comentario": "Ciclo: cada tipo é forte contra o próximo da lista e fraco contra o anterior. Reordene 'types' para mudar o ciclo.",
        "strong_mult": 1.5,
        "weak_mult": 0.67,
        "neutral_mult": 1.0,
        "types": [{"id": t[0], "name": t[1], "color": t[2]} for t in TYPES],
    })


def gen_abilities():
    abilities = {}
    for t in TYPE_IDS:
        for i, kind in enumerate(ABILITY_KINDS):
            a = dict(ABILITY_TEMPLATE[kind])
            a["id"] = "%s_%s" % (t, kind)
            a["name"] = ABILITY_NAMES[t][i]
            a["type"] = t
            a["kind"] = kind
            abilities[a["id"]] = a
    wjson("abilities.json", {"abilities": abilities})


def gen_families():
    fams = []
    for ti, t in enumerate(TYPE_IDS):
        for fi, (names, shape, style, concept, starter) in enumerate(FAMILIES[t]):
            rnd = random.Random("%s-%d" % (t, fi))
            base = dict(STYLE_BASE[style])
            for k, m in SHAPE_MOD[shape].items():
                base[k] = base[k] * m
            for k in ("hp", "atk", "def"):
                base[k] = round(base[k] * rnd.uniform(0.95, 1.05), 2)
            base["spd"] = round(base["spd"], 1)
            fid = "%s_%d" % (t, fi + 1)
            stages = []
            for s in range(3):
                c = concept
                desc = STAGE_DESC[s].format(c=c, c2=STAGE_EXTRA2[style], c3=STAGE_EXTRA3[style])
                stages.append({
                    "form_id": "%s_%d" % (fid, s + 1),
                    "name": names[s],
                    "stage": s + 1,
                    "desc": desc,
                    "abilities": ["%s_%s" % (t, k) for k in STYLE_ABILITIES[style][s]],
                })
            fams.append({
                "id": fid,
                "type": t,
                "shape": shape,
                "style": style,
                "starter": starter,
                "evo_levels": [16, 35],
                "essence_mult": 1.5 if starter else round(rnd.uniform(0.9, 1.2), 2),
                "hue_shift": round((fi - 2) * 0.035, 3),
                "base": base,
                "stages": stages,
            })
    wjson("families.json", {
        "_comentario": "45 famílias, 3 estágios cada. 'base' = atributos no nível 1 do Filhote. Crescimento por nível e bônus por estágio ficam em config.json.",
        "families": fams,
    })
    return fams


def biome_for_types(types):
    tset = set(types)
    if len(tset) == 1:
        return None
    for b in BIOMES:
        if len(b[2]) > 1 and set(b[2]) == tset:
            return b[0]
    for b in BIOMES:
        if len(b[2]) > 1 and tset.issubset(set(b[2])):
            return b[0]
    return None


def gen_biomes():
    out = []
    for b in BIOMES:
        out.append({
            "id": b[0], "name": b[1], "types": b[2], "gen": b[3], "wall_style": b[4], "deco_style": b[5],
            "floor": b[6], "wall": b[7], "deco": b[8],
        })
    wjson("biomes.json", {
        "_comentario": "Paletas e estilos de geração por bioma. Mundo 2 aplica 'corruption' do config.json sobre estas paletas.",
        "biomes": out,
    })


def sub_biomes(t):
    return [b[0] for b in BIOMES if b[2] == [t]]


def drop_bases(types, level, rnd, world2=False):
    # bases de item tematicas pelos tipos da hunt, do tier adequado ao nivel
    tier = 1
    for tr in TIERS:
        if tr["level"] <= level and (world2 or not tr["world2"]):
            tier = tr["tier"]
    tiers = [tier] if tier == 1 else [tier - 1, tier]
    out = []
    for t in types:
        for tr in tiers:
            for s in SLOTS:
                out.append({"base": "%s_%s_t%d" % (s[0], t, tr), "weight": 3 if tr == tier else 1})
    rnd.shuffle(out)
    return out[:10]


def place_name(biome, rnd, used):
    for _ in range(200):
        n = "%s %s" % (rnd.choice(PLACE_NOUN[biome]), rnd.choice(PLACE_ADJ))
        if n not in used:
            used.add(n)
            return n
    return "%s %d" % (biome, len(used))


def gen_hunts(fams):
    rnd = random.Random(424242)
    used = set()
    hunts = []
    by_type = {t: [f for f in fams if f["type"] == t] for t in TYPE_IDS}
    groups = [
        (["agua", "planta", "vento"], 1, [1, 2, 3, 4, 5]),
        (["fogo", "terra", "luz"], 6, [6, 7, 8, 9, 10]),
        (["gelo", "eletrico", "sombra"], 12, [12, 13, 14, 15, 15]),
    ]
    # Filhotes
    for types, unlock, levels in groups:
        for t in types:
            for fi, f in enumerate(by_type[t]):
                lvl = levels[fi]
                biome = sub_biomes(t)[fi % len(sub_biomes(t))]
                form = f["stages"][0]["form_id"]
                hunts.append(make_hunt("w1_s1_%s" % f["id"], place_name(biome, rnd, used), lvl, unlock, biome,
                                       [t], [{"form": form, "weight": 1}], 14, 10.0, 40, rnd, "filhote"))
    # Adolescentes: intercalar tipos para variar
    order = []
    for fi in range(5):
        for t in TYPE_IDS:
            order.append(by_type[t][fi])
    for i, f in enumerate(order):
        lvl = 16 + (i * 19) // 45
        t = f["type"]
        biome = sub_biomes(t)[i % len(sub_biomes(t))]
        hunts.append(make_hunt("w1_s2_%s" % f["id"], place_name(biome, rnd, used), lvl, max(16, lvl - 2), biome,
                               [t], [{"form": f["stages"][1]["form_id"], "weight": 1}], 16, 10.0, 44, rnd, "adolescente"))
    # Adultos
    for i, f in enumerate(order):
        lvl = 35 + (i * 46) // 45
        t = f["type"]
        biome = sub_biomes(t)[(i + 1) % len(sub_biomes(t))]
        hunts.append(make_hunt("w1_s3_%s" % f["id"], place_name(biome, rnd, used), lvl, max(35, lvl - 3), biome,
                               [t], [{"form": f["stages"][2]["form_id"], "weight": 1}], 18, 10.0, 48, rnd, "adulto"))
    # Hunts mistas (biomas de transicao)
    mixed = [
        ("pantano", ["agua", "planta"], 1, 20), ("fontes_termais", ["agua", "fogo"], 1, 24),
        ("deserto_cinzas", ["fogo", "terra"], 1, 28), ("geleira_rochosa", ["gelo", "terra"], 1, 32),
        ("brejo_sombrio", ["sombra", "planta"], 2, 42), ("crepusculo", ["luz", "sombra"], 2, 52),
        ("geleira_eterea", ["gelo", "vento"], 2, 62), ("tempestade_luminosa", ["eletrico", "luz"], 2, 70),
        ("cordilheira_ventosa", ["vento", "terra", "eletrico"], 2, 78),
    ]
    for biome, types, stage_idx, lvl in mixed:
        monsters = []
        for t in types:
            for f in rnd.sample(by_type[t], 2):
                monsters.append({"form": f["stages"][stage_idx]["form_id"], "weight": 1})
        unlock = max(16 if stage_idx == 1 else 35, lvl - 3)
        hunts.append(make_hunt("w1_mix_%s" % biome, place_name(biome, rnd, used), lvl, unlock, biome, types, monsters,
                               20, 9.0, 52, rnd, "mista"))
    hunts.sort(key=lambda h: (h["level"], h["id"]))
    wjson("hunts_world1.json", {
        "_comentario": "Hunts do Mundo 1. density = monstros simultâneos; respawn em segundos; map_size em tiles. Hunts do Mundo 2 são geradas pelo config.json (world2).",
        "hunts": hunts,
    })
    return hunts


def requires_challenge(level):
    c = ((level - 1) // 10) * 10
    return c if 10 <= c <= 80 else 0


def make_hunt(hid, name, lvl, unlock, biome, types, monsters, density, respawn, size, rnd, category):
    return {
        "id": hid, "name": name, "world": 1, "category": category, "level": lvl, "unlock_level": unlock,
        "requires_challenge": requires_challenge(lvl), "biome": biome, "types": types, "monsters": monsters,
        "density": density, "respawn": respawn, "map_size": [size, size], "seed": rnd.randint(1, 2**30),
        "recruit": True, "recruit_mult": 1.0, "xp_mult": 1.0, "gold_mult": 1.0,
        "drops": drop_bases(types, lvl, rnd),
    }


BOSSES = [
    (10, "Gotelão, o Rei das Poças", "agua_1_2", "praia", {"summon": {"form": "agua_2_1", "every": 12, "count": 2}}),
    (20, "Brasalfa, Lobo-Tocha", "fogo_1_2", "vulcao", {"aoe": {"every": 9, "count": 3, "radius": 1, "dmg_pct": 0.18, "telegraph": 1.6}}),
    (30, "Ramagueira Anciã", "planta_1_2", "floresta_densa", {"summon": {"form": "planta_4_2", "every": 11, "count": 2}, "aoe": {"every": 10, "count": 2, "radius": 1, "dmg_pct": 0.16, "telegraph": 1.6}}),
    (40, "Monolitauro Desperto", "terra_1_3", "caverna_rochosa", {"aoe": {"every": 8, "count": 4, "radius": 1, "dmg_pct": 0.2, "telegraph": 1.5}}),
    (50, "Glaciafera Branca", "gelo_2_3", "caverna_congelada", {"summon": {"form": "gelo_1_2", "every": 10, "count": 3}}),
    (60, "Trovajante Tirano", "eletrico_1_3", "ruinas_energizadas", {"summon": {"form": "eletrico_3_2", "every": 11, "count": 2}, "aoe": {"every": 8, "count": 3, "radius": 1, "dmg_pct": 0.2, "telegraph": 1.4}}),
    (70, "Furacondor Ancestral", "vento_1_3", "plataformas_nuvens", {"aoe": {"every": 7, "count": 5, "radius": 1, "dmg_pct": 0.18, "telegraph": 1.4}}),
    (80, "Auréolux, o Juiz", "luz_1_3", "templo", {"summon": {"form": "luz_3_2", "every": 10, "count": 3}, "aoe": {"every": 7, "count": 4, "radius": 2, "dmg_pct": 0.16, "telegraph": 1.5}}),
    (90, "Eclipsauro Primordial", "sombra_1_3", "cemiterio", {"summon": {"form": "sombra_2_3", "every": 9, "count": 3}, "aoe": {"every": 6, "count": 5, "radius": 1, "dmg_pct": 0.2, "telegraph": 1.3}}),
]


def gen_challenges():
    out = []
    for lvl, name, form, biome, mech in BOSSES:
        t = form.split("_")[0]
        reward_rarity = "raro" if lvl <= 30 else ("epico" if lvl <= 60 else "lendario")
        c = {
            "id": "c%d" % lvl, "level": lvl, "name": name, "boss_form": form, "type": t, "biome": biome,
            "boss_level": lvl + 2, "hp_mult": 30.0, "atk_mult": 1.5, "def_mult": 1.2, "scale": 1.6,
            "phases": [{"hp_below": 0.5, "atk_mult": 1.3, "spd_mult": 1.2, "say": "Fase 2: o chefe se enfurece!"}],
            "mechanics": mech, "time_limit": 240,
            "rewards": {"gold": 500 * lvl, "essence": {t: 40 * lvl // 10}, "item_rarity": reward_rarity},
            "unlocks": ("world2" if lvl == 80 else ""), "map_size": [26, 26], "seed": 1000 + lvl,
        }
        out.append(c)
    wjson("challenges.json", {
        "_comentario": "Desafios (bosses). Para adicionar desafios acima de 90, inclua novas entradas aqui.",
        "fail_cooldown_seconds": 60,
        "challenges": out,
    })


def gen_items():
    bases = {}
    for tr in TIERS:
        for t in TYPE_IDS:
            for sid, sname, stat, nouns in SLOTS:
                noun = nouns[tr["tier"] - 1]
                adj = TYPE_ADJ_F[t] if noun in FEMININE else TYPE_ADJ[t]
                bid = "%s_%s_t%d" % (sid, t, tr["tier"])
                bases[bid] = {
                    "id": bid, "name": "%s %s" % (noun, adj), "slot": sid, "type": t, "tier": tr["tier"],
                    "level": tr["level"], "world2_only": tr["world2"], "main_stat": stat,
                }
    affixes = [
        {"id": "hp_pct", "name": "+{v}% HP", "stat": "hp_pct", "min": 3, "max": 10},
        {"id": "atk_pct", "name": "+{v}% Ataque", "stat": "atk_pct", "min": 3, "max": 10},
        {"id": "def_pct", "name": "+{v}% Defesa", "stat": "def_pct", "min": 3, "max": 10},
        {"id": "spd_pct", "name": "+{v}% Velocidade", "stat": "spd_pct", "min": 2, "max": 6},
        {"id": "crit", "name": "+{v}% Crítico", "stat": "crit", "min": 1, "max": 5},
        {"id": "lifesteal", "name": "+{v}% Roubo de vida", "stat": "lifesteal", "min": 1, "max": 4},
        {"id": "cdr", "name": "-{v}% Recarga de habilidades", "stat": "cdr", "min": 2, "max": 8},
        {"id": "xp_pct", "name": "+{v}% XP", "stat": "xp_pct", "min": 1, "max": 5},
        {"id": "gold_pct", "name": "+{v}% Ouro", "stat": "gold_pct", "min": 2, "max": 8},
        {"id": "type_dmg", "name": "+{v}% dano contra {t}", "stat": "type_dmg", "min": 4, "max": 12, "per_type": True},
    ]
    wjson("items.json", {
        "_comentario": "Bases de itens (slot x tipo x tier) e afixos. Valores base dos atributos por slot em config.json (items).",
        "slots": [{"id": s[0], "name": s[1], "main_stat": s[2]} for s in SLOTS],
        "tiers": TIERS,
        "bases": bases,
        "affixes": affixes,
        "shop": {"_comentario": "A loja NPC vende bases Comum dos tiers liberados.", "rarity": "comum", "price_mult": 3.0},
    })


if __name__ == "__main__":
    os.makedirs(DATA, exist_ok=True)
    gen_types()
    gen_abilities()
    fams = gen_families()
    gen_biomes()
    gen_hunts(fams)
    gen_challenges()
    gen_items()
