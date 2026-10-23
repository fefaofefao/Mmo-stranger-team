#!/usr/bin/env python3
"""Gerador do conteúdo base (JSON em data/), com textos em PT-BR, EN e ES.

Os arquivos JSON em data/ são a fonte da verdade do jogo. Este script (re)cria o conteúdo base.
Ajustes manuais nos JSON de conteúdo são sobrescritos ao rodar de novo, EXCETO:
  - data/config.json, data/ads.json, data/backend.json (nunca tocados)
  - calibração dos chefes em data/challenges.json (hp_mult, atk_mult, def_mult, mechanics) — preservada

Textos traduzíveis são objetos {"pt_BR": ..., "en": ..., "es": ...}. Nomes de monstros são nomes
próprios (iguais em todos os idiomas), como em qualquer jogo de monstros.

Uso:  python3 tools/gen_data.py
"""
import json
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
LANGS = ["pt_BR", "en", "es"]


def L(pt, en, es):
    return {"pt_BR": pt, "en": en, "es": es}


TYPES = [
    ("agua", L("Água", "Water", "Agua"), "#3b7fd9"),
    ("fogo", L("Fogo", "Fire", "Fuego"), "#e0522b"),
    ("gelo", L("Gelo", "Ice", "Hielo"), "#7fd6e8"),
    ("planta", L("Planta", "Plant", "Planta"), "#4caf3f"),
    ("terra", L("Terra", "Earth", "Tierra"), "#a8743a"),
    ("eletrico", L("Elétrico", "Electric", "Eléctrico"), "#f2d023"),
    ("vento", L("Vento", "Wind", "Viento"), "#94bfe0"),
    ("luz", L("Luz", "Light", "Luz"), "#f5c94e"),
    ("sombra", L("Sombra", "Shadow", "Sombra"), "#6a3d9a"),
]
TYPE_IDS = [t[0] for t in TYPES]

# Cada família = um animal fundido com o seu elemento.
# (nomes dos 3 estágios, formato do corpo, estilo, traços visuais, conceito PT/EN/ES, inicial?)
FAMILIES = {
    "agua": [
        (["Marolinho", "Marolontra", "Tsunontra"], "quadruped", "magic", {"ears": "round", "tail": "fin", "whiskers": True, "belly": True},
         L("uma lontrinha brincalhona que surfa nas próprias ondas", "a playful otter pup that surfs on its own waves", "una nutria juguetona que surfea sus propias olas"), True),
        (["Girinho", "Sapoça", "Trombasapo"], "blob", "ranged", {"frog": True, "belly": True},
         L("um sapinho que cospe jatos d'água certeiros", "a little frog that spits precise water jets", "una ranita que escupe chorros de agua certeros"), False),
        (["Axolito", "Axolago", "Axoceano"], "biped", "magic", {"gills": True, "tail": "thin", "belly": True},
         L("um axolote sorridente que regenera tudo ao seu redor", "a smiling axolotl that heals everything around it", "un ajolote sonriente que regenera todo a su alrededor"), False),
        (["Bolhuga", "Tartaonda", "Maremotuga"], "golem", "melee", {"shell": True, "ears": "none"},
         L("uma tartaruguinha que carrega um aquário no casco", "a tiny turtle carrying an aquarium on its shell", "una tortuguita que lleva un acuario en el caparazón"), False),
        (["Dentuguinho", "Tuborrão", "Megalodágua"], "fish", "melee", {"fin_back": True, "teeth": True, "belly": True},
         L("um tubarãozinho banguela que morde mesmo assim", "a toothless little shark that bites anyway", "un tiburoncito chimuelo que muerde igual"), False),
    ],
    "fogo": [
        (["Fogarito", "Raposbrasa", "Infernaposa"], "quadruped", "melee", {"ears": "pointy", "tail": "fluffy", "belly": True},
         L("um filhote de raposa com a cauda acesa como uma tocha", "a fox cub whose tail burns like a torch", "un zorrito con la cola encendida como una antorcha"), True),
        (["Lagartiço", "Lagartocha", "Magmagarto"], "quadruped", "ranged", {"ears": "none", "tail": "thin", "spikes": True, "low": True},
         L("um lagartinho que cospe brasas quando espirra", "a little lizard that spits embers when it sneezes", "un lagartito que escupe brasas al estornudar"), False),
        (["Pintochinha", "Galabrasa", "Fenigalo"], "bird", "ranged", {"crest": True, "tail_feathers": True},
         L("um pintinho que acorda o vulcão todo dia de manhã", "a chick that wakes the volcano up every morning", "un pollito que despierta al volcán cada mañana"), False),
        (["Torreminho", "Javabrasa", "Vulcajavali"], "quadruped", "melee", {"ears": "round", "horns": "tusks", "tail": "curl", "snout": True},
         L("um porquinho de lava que adora rolar nas cinzas", "a lava piglet that loves rolling in ashes", "un cerdito de lava al que le encanta revolcarse en ceniza"), False),
        (["Cinzarola", "Mariposeira", "Incendiposa"], "insect", "magic", {"wings": "butterfly", "antennae": True},
         L("uma mariposa atraída por qualquer chama, inclusive a própria", "a moth drawn to any flame, even its own", "una polilla atraída por cualquier llama, incluso la suya"), False),
    ],
    "gelo": [
        (["Picolino", "Pinguelado", "Imperinverno"], "bird", "ranged", {"penguin": True},
         L("um pinguinzinho que escorrega de barriga em qualquer superfície", "a little penguin that belly-slides on any surface", "un pingüinito que se desliza de panza por cualquier superficie"), True),
        (["Miaugelo", "Gatoneve", "Leoparvalanche"], "quadruped", "melee", {"ears": "pointy", "tail": "thin", "whiskers": True, "spots": True},
         L("um gatinho das neves que tira sonecas em montes de gelo", "a snow kitten that naps on piles of ice", "un gatito de las nieves que duerme sobre montones de hielo"), False),
        (["Ursorvete", "Ursofrio", "Glaciursão"], "golem", "melee", {"ears": "round", "snout": True, "belly": True},
         L("um ursinho polar com cheiro de sorvete de baunilha", "a polar bear cub that smells like vanilla ice cream", "un osito polar con olor a helado de vainilla"), False),
        (["Floquinha", "Focagelo", "Morsavalanche"], "fish", "ranged", {"seal": True, "whiskers": True, "teeth": True},
         L("uma foquinha que faz malabarismo com bolas de neve", "a little seal that juggles snowballs", "una focita que hace malabares con bolas de nieve"), False),
        (["Geadinha", "Corugeada", "Nevascoruja"], "bird", "magic", {"owl": True},
         L("uma corujinha que congela o ar quando pisca", "a tiny owl that freezes the air when it blinks", "una lechucita que congela el aire al parpadear"), False),
    ],
    "planta": [
        (["Brotilho", "Cervilha", "Cervoresta"], "quadruped", "melee", {"ears": "long", "antlers": True, "tail": "fluffy", "spots": True},
         L("um filhote de cervo com brotos nascendo nos chifres", "a fawn with sprouts growing from its antlers", "un cervatillo con brotes creciendo en sus astas"), True),
        (["Folhagarta", "Casulhoso", "Borbolhagem"], "insect", "ranged", {"wings": "butterfly", "larva": True, "antennae": True},
         L("uma lagartinha que se esconde debaixo das folhas", "a little caterpillar that hides under leaves", "una orugita que se esconde bajo las hojas"), False),
        (["Camalimo", "Camaleira", "Camaleflora"], "biped", "magic", {"chameleon": True, "tail": "curl"},
         L("um camaleão que vira um canteiro de flores quando fica feliz", "a chameleon that turns into a flowerbed when happy", "un camaleón que se vuelve un jardín cuando está feliz"), False),
        (["Ouricacto", "Espinhouriço", "Cactourão"], "quadruped", "melee", {"ears": "round", "spikes": True, "snout": True, "low": True},
         L("um ouriço-cacto que dá abraços bem espinhosos", "a cactus hedgehog that gives very prickly hugs", "un erizo-cactus que da abrazos muy espinosos"), False),
        (["Beijolim", "Beijaflora", "Orquidebico"], "bird", "ranged", {"hummingbird": True},
         L("um beija-flor que planta sementes por onde voa", "a hummingbird that plants seeds wherever it flies", "un colibrí que planta semillas por donde vuela"), False),
    ],
    "terra": [
        (["Tatuzito", "Tatupedra", "Tatuzólito"], "quadruped", "melee", {"ears": "round", "shell": True, "tail": "thin", "snout": True},
         L("um tatuzinho que vira uma bola de pedra quando se assusta", "an armadillo pup that rolls into a stone ball when scared", "un armadillito que se vuelve una bola de piedra al asustarse"), True),
        (["Cavuquinho", "Toupeiroca", "Terratoupe"], "quadruped", "melee", {"ears": "none", "glasses": True, "whiskers": True, "snout": True, "low": True},
         L("uma toupeira de óculos que cava túneis em segundos", "a mole with glasses that digs tunnels in seconds", "un topo con gafas que cava túneles en segundos"), False),
        (["Rinozinho", "Rinocascalho", "Rinomonte"], "quadruped", "melee", {"horns": "one", "ears": "round"},
         L("um rinoceronte pequenino com um chifre de quartzo", "a tiny rhino with a quartz horn", "un rinoceronte pequeñito con un cuerno de cuarzo"), False),
        (["Escorpito", "Escorpedra", "Duneorpião"], "insect", "ranged", {"scorpion": True},
         L("um escorpião de areia que balança a cauda para cumprimentar", "a sand scorpion that waves its tail to say hello", "un escorpión de arena que mueve la cola para saludar"), False),
        (["Lamacaquinho", "Gorilama", "Gorilamonte"], "biped", "melee", {"ape": True, "ears": "round"},
         L("um macaquinho de barro que bate no peito para tremer o chão", "a clay monkey that beats its chest to shake the ground", "un monito de barro que se golpea el pecho para sacudir el suelo"), False),
    ],
    "eletrico": [
        (["Lãmpadinha", "Lãmpadão", "Carneiraio"], "quadruped", "ranged", {"wool": True, "horns": "curl", "ears": "round"},
         L("uma ovelhinha cuja lã acumula estática e acende no escuro", "a lamb whose wool builds up static and glows in the dark", "una ovejita cuya lana acumula estática y brilla en la oscuridad"), True),
        (["Choquinha", "Enguiraio", "Trovaenguia"], "serpent", "ranged", {"fin_back": True},
         L("uma enguia que dá choquinhos de carinho", "an eel that gives affectionate little shocks", "una anguila que da toquecitos de cariño"), False),
        (["Zumbito", "Abelhampère", "Vespatrovão"], "insect", "melee", {"bee": True, "wings": "bee", "antennae": True},
         L("uma abelhinha que produz mel com gosto de bateria", "a little bee that makes honey that tastes like batteries", "una abejita que hace miel con sabor a batería"), False),
        (["Pardaraio", "Gaviraio", "Tempestaguia"], "bird", "magic", {"crest": True, "tail_feathers": True},
         L("um passarinho que pousa nos fios e nunca leva choque", "a little bird that perches on power lines and never gets shocked", "un pajarito que se posa en los cables y nunca se electrocuta"), False),
        (["Vivinha", "Voltaviva", "Megaviva"], "spirit", "magic", {"jelly": True},
         L("uma água-viva que brilha como lâmpada fluorescente", "a jellyfish that glows like a fluorescent lamp", "una medusa que brilla como lámpara fluorescente"), False),
    ],
    "vento": [
        (["Brisinho", "Lebrisa", "Lebreventania"], "quadruped", "ranged", {"ears": "long", "tail": "puff", "belly": True},
         L("um coelhinho tão leve que o vento leva para passear", "a bunny so light the wind takes it for walks", "un conejito tan ligero que el viento lo saca a pasear"), True),
        (["Andorisa", "Andorrajada", "Ciclondor"], "bird", "ranged", {"tail_feathers": True, "swallow": True},
         L("uma andorinha que desenha redemoinhos no céu", "a swallow that draws whirlwinds in the sky", "una golondrina que dibuja remolinos en el cielo"), False),
        (["Libelinha", "Libelâmina", "Ceifavento"], "insect", "melee", {"wings": "dragonfly"},
         L("uma libélula de asas afiadas como lâminas", "a dragonfly with wings sharp as blades", "una libélula de alas afiladas como cuchillas"), False),
        (["Cabritinho", "Cabrisopro", "Cabritormenta"], "quadruped", "melee", {"horns": "curl", "ears": "pointy", "beard": True},
         L("um cabrito que salta de nuvem em nuvem", "a little goat that hops from cloud to cloud", "un cabrito que salta de nube en nube"), False),
        (["Nuvélio", "Nimbosserpe", "Dragonimbo"], "serpent", "magic", {"cloud": True},
         L("uma cobrinha feita de nuvem que adora fazer chover", "a little cloud serpent that loves making it rain", "una serpientita de nube a la que le encanta hacer llover"), False),
    ],
    "luz": [
        (["Potrilume", "Corcelux", "Alvorcorno"], "quadruped", "melee", {"ears": "pointy", "horns": "one", "mane": True, "tail": "fluffy"},
         L("um potrinho de crina luminosa que galopa ao nascer do sol", "a foal with a glowing mane that gallops at sunrise", "un potrillo de crin luminosa que galopa al amanecer"), True),
        (["Pavelinho", "Pavaluz", "Solpavão"], "bird", "ranged", {"peacock": True, "crest": True},
         L("um pavãozinho que abre a cauda e ilumina a floresta", "a peachick that fans its tail and lights up the forest", "un pavito que abre la cola e ilumina el bosque"), False),
        (["Vagalumito", "Vagaluzeiro", "Supernovalume"], "insect", "magic", {"firefly": True, "wings": "bee", "antennae": True},
         L("um vaga-lume que guia viajantes perdidos", "a firefly that guides lost travelers", "una luciérnaga que guía a viajeros perdidos"), False),
        (["Leãozito", "Solião", "Aurileão"], "quadruped", "melee", {"ears": "round", "mane": True, "tail": "tuft"},
         L("um leãozinho com juba de raios de sol", "a lion cub with a mane of sunbeams", "un leoncito con melena de rayos de sol"), False),
        (["Lampeixinho", "Lanterpeixe", "Abissoluz"], "fish", "magic", {"lure": True, "teeth": True},
         L("um peixe-lanterna que ilumina as profundezas", "a lanternfish that lights up the depths", "un pez linterna que ilumina las profundidades"), False),
    ],
    "sombra": [
        (["Breuzinho", "Lobreu", "Eclipsilobo"], "quadruped", "melee", {"ears": "pointy", "tail": "fluffy", "belly": True},
         L("um lobinho feito de breu que uiva para a lua nova", "a wolf pup made of pitch that howls at the new moon", "un lobezno hecho de brea que aúlla a la luna nueva"), True),
        (["Vultinho", "Morcevulto", "Noturcego"], "bird", "magic", {"bat": True},
         L("um morceguinho que dorme de cabeça para baixo nas sombras", "a little bat that sleeps upside down in the shadows", "un murcielaguito que duerme boca abajo en las sombras"), False),
        (["Corvito", "Corvoturvo", "Nocturnave"], "bird", "ranged", {"crest": True, "tail_feathers": True},
         L("um corvo de olhos vermelhos que coleciona coisas brilhantes", "a red-eyed crow that collects shiny things", "un cuervo de ojos rojos que colecciona cosas brillantes"), False),
        (["Aranhoca", "Tecelúgubre", "Viúvanoite"], "insect", "melee", {"spider": True},
         L("uma aranha que tece teias de escuridão", "a spider that weaves webs of darkness", "una araña que teje redes de oscuridad"), False),
        (["Tintinha", "Polvoscuro", "Krakenoite"], "blob", "magic", {"octopus": True},
         L("um polvinho que solta tinta de sombra quando fica tímido", "a little octopus that squirts shadow ink when shy", "un pulpito que suelta tinta de sombra cuando se pone tímido"), False),
    ],
}

SPECIES = {'agua_1': ('uma lontra das marés', 'a tide otter', 'una nutria de las mareas'), 'agua_2': ("um sapo-tromba-d'água", 'a waterspout frog', 'una rana tromba de agua'), 'agua_3': ('um axolote abissal', 'an abyssal axolotl', 'un ajolote abisal'), 'agua_4': ('uma tartaruga-maremoto', 'a tidal-wave turtle', 'una tortuga maremoto'), 'agua_5': ('um tubarão das correntezas', 'a riptide shark', 'un tiburón de las corrientes'), 'fogo_1': ('uma raposa incandescente', 'a blazing fox', 'un zorro incandescente'), 'fogo_2': ('um lagarto de magma', 'a magma lizard', 'un lagarto de magma'), 'fogo_3': ('um galo-fênix', 'a phoenix rooster', 'un gallo fénix'), 'fogo_4': ('um javali vulcânico', 'a volcanic boar', 'un jabalí volcánico'), 'fogo_5': ('uma mariposa incendiária', 'an incendiary moth', 'una polilla incendiaria'), 'gelo_1': ('um pinguim imperial do inverno', 'an imperial winter penguin', 'un pingüino imperial del invierno'), 'gelo_2': ('um leopardo das avalanches', 'an avalanche leopard', 'un leopardo de las avalanchas'), 'gelo_3': ('um urso glacial', 'a glacial bear', 'un oso glacial'), 'gelo_4': ('uma morsa das nevascas', 'a blizzard walrus', 'una morsa de las ventiscas'), 'gelo_5': ('uma coruja da nevasca', 'a snowstorm owl', 'una lechuza de la ventisca'), 'planta_1': ('um cervo-floresta', 'a forest stag', 'un ciervo bosque'), 'planta_2': ('uma borboleta de folhagem', 'a foliage butterfly', 'una mariposa de follaje'), 'planta_3': ('um camaleão florido', 'a blooming chameleon', 'un camaleón florido'), 'planta_4': ('um ouriço-cacto gigante', 'a giant cactus hedgehog', 'un erizo-cactus gigante'), 'planta_5': ('um beija-flor orquídea', 'an orchid hummingbird', 'un colibrí orquídea'), 'terra_1': ('um tatu de rocha viva', 'a living-rock armadillo', 'un armadillo de roca viva'), 'terra_2': ('uma toupeira escavadora', 'a burrowing mole', 'un topo excavador'), 'terra_3': ('um rinoceronte-montanha', 'a mountain rhino', 'un rinoceronte montaña'), 'terra_4': ('um escorpião das dunas', 'a dune scorpion', 'un escorpión de las dunas'), 'terra_5': ('um gorila de barro', 'a clay gorilla', 'un gorila de barro'), 'eletrico_1': ('um carneiro de trovão', 'a thunder ram', 'un carnero del trueno'), 'eletrico_2': ('uma enguia-tempestade', 'a storm eel', 'una anguila tormenta'), 'eletrico_3': ('uma vespa-trovão', 'a thunder wasp', 'una avispa trueno'), 'eletrico_4': ('uma águia da tempestade', 'a tempest eagle', 'un águila de la tormenta'), 'eletrico_5': ('uma água-viva de alta voltagem', 'a high-voltage jellyfish', 'una medusa de alto voltaje'), 'vento_1': ('uma lebre-ventania', 'a gale hare', 'una liebre vendaval'), 'vento_2': ('uma andorinha-ciclone', 'a cyclone swallow', 'una golondrina ciclón'), 'vento_3': ('uma libélula ceifadora', 'a reaper dragonfly', 'una libélula segadora'), 'vento_4': ('um bode da tormenta', 'a squall goat', 'un macho cabrío de la tormenta'), 'vento_5': ('um dragão de nuvem', 'a cloud dragon', 'un dragón de nube'), 'luz_1': ('um unicórnio da aurora', 'a dawn unicorn', 'un unicornio del alba'), 'luz_2': ('um pavão solar', 'a solar peacock', 'un pavo real solar'), 'luz_3': ('um vaga-lume estelar', 'a stellar firefly', 'una luciérnaga estelar'), 'luz_4': ('um leão dourado', 'a golden lion', 'un león dorado'), 'luz_5': ('um peixe-lanterna abissal', 'an abyssal lanternfish', 'un pez linterna abisal'), 'sombra_1': ('um lobo do eclipse', 'an eclipse wolf', 'un lobo del eclipse'), 'sombra_2': ('um morcego noturno', 'a nocturnal bat', 'un murciélago nocturno'), 'sombra_3': ('um corvo da noite', 'a night crow', 'un cuervo de la noche'), 'sombra_4': ('uma viúva da noite', 'a night widow', 'una viuda de la noche'), 'sombra_5': ('um kraken das sombras', 'a shadow kraken', 'un kraken de las sombras')}

STAGE_DESC = {
    "pt_BR": ["Filhote: {c}.", "Adolescente: {sp} que {x}.", "Adulto: {sp}, {x}."],
    "en": ["Baby: {c}.", "Teen: {sp} that {x}.", "Adult: {sp}, {x}."],
    "es": ["Cría: {c}.", "Adolescente: {sp} que {x}.", "Adulto: {sp}, {x}."],
}
STAGE_EXTRA = {
    "pt_BR": [{"melee": "ficou forte e parte para o corpo a corpo sem medo", "ranged": "aprendeu a acertar alvos de longe", "magic": "começou a dominar feitiços de área"},
              {"melee": "uma fera capaz de derrubar grupos inteiros", "ranged": "um atirador implacável de longo alcance", "magic": "sua magia transforma o campo de batalha"}],
    "en": [{"melee": "grew strong and charges into melee fearlessly", "ranged": "learned to hit targets from afar", "magic": "began mastering area spells"},
           {"melee": "a beast able to topple whole packs", "ranged": "a relentless long-range sharpshooter", "magic": "its magic reshapes the battlefield"}],
    "es": [{"melee": "se hizo fuerte y se lanza al cuerpo a cuerpo sin miedo", "ranged": "aprendió a acertar blancos de lejos", "magic": "empezó a dominar hechizos de área"},
           {"melee": "una bestia capaz de derribar manadas enteras", "ranged": "un tirador implacable de largo alcance", "magic": "su magia transforma el campo de batalla"}],
}

# Habilidades: strike, bolt, burst, blast, heal, dot, ult
ABILITY_NAMES = {
    "agua": (["Pancada de Maré", "Jato d'Água", "Onda Circular", "Bomba de Bolhas", "Névoa Restauradora", "Correnteza", "Tsunami"],
             ["Tide Slam", "Water Jet", "Ring Wave", "Bubble Bomb", "Healing Mist", "Undertow", "Tsunami"],
             ["Golpe de Marea", "Chorro de Agua", "Onda Circular", "Bomba de Burbujas", "Niebla Curativa", "Corriente", "Tsunami"]),
    "fogo": (["Garra Flamejante", "Bola de Fogo", "Explosão de Brasas", "Chuva de Lava", "Calor Vital", "Queimadura", "Erupção"],
             ["Flame Claw", "Fireball", "Ember Burst", "Lava Rain", "Vital Heat", "Scorch", "Eruption"],
             ["Garra Llameante", "Bola de Fuego", "Estallido de Brasas", "Lluvia de Lava", "Calor Vital", "Quemadura", "Erupción"]),
    "gelo": (["Mordida Gélida", "Estilhaço de Gelo", "Anel de Geada", "Granizo", "Casulo de Gelo", "Congelamento", "Nevasca"],
             ["Frost Bite", "Ice Shard", "Frost Ring", "Hailstorm", "Ice Cocoon", "Deep Freeze", "Blizzard"],
             ["Mordida Gélida", "Esquirla de Hielo", "Anillo de Escarcha", "Granizo", "Capullo de Hielo", "Congelación", "Ventisca"]),
    "planta": (["Chicote de Vinha", "Semente Bala", "Anel de Espinhos", "Explosão de Pólen", "Fotossíntese", "Esporos Tóxicos", "Fúria da Floresta"],
               ["Vine Whip", "Seed Bullet", "Thorn Ring", "Pollen Burst", "Photosynthesis", "Toxic Spores", "Forest Fury"],
               ["Látigo de Vid", "Semilla Bala", "Anillo de Espinas", "Estallido de Polen", "Fotosíntesis", "Esporas Tóxicas", "Furia del Bosque"]),
    "terra": (["Pancada Rochosa", "Arremesso de Pedra", "Tremor", "Desabamento", "Pele de Pedra", "Areia Movediça", "Terremoto"],
              ["Rock Smash", "Stone Throw", "Tremor", "Rockslide", "Stone Skin", "Quicksand", "Earthquake"],
              ["Golpe Rocoso", "Lanzar Piedra", "Temblor", "Derrumbe", "Piel de Piedra", "Arenas Movedizas", "Terremoto"]),
    "eletrico": (["Ferrão Voltaico", "Faísca", "Descarga", "Raio Concentrado", "Recarga", "Estática", "Tempestade de Raios"],
                 ["Volt Sting", "Spark", "Discharge", "Focused Bolt", "Recharge", "Static", "Thunderstorm"],
                 ["Aguijón Voltaico", "Chispa", "Descarga", "Rayo Concentrado", "Recarga", "Estática", "Tormenta de Rayos"]),
    "vento": (["Corte de Ar", "Rajada", "Redemoinho", "Lâminas de Vento", "Brisa Curativa", "Vendaval", "Furacão"],
              ["Air Cut", "Gust", "Whirlwind", "Wind Blades", "Healing Breeze", "Gale", "Hurricane"],
              ["Corte de Aire", "Ráfaga", "Remolino", "Cuchillas de Viento", "Brisa Curativa", "Vendaval", "Huracán"]),
    "luz": (["Golpe Radiante", "Raio de Sol", "Clarão", "Coluna de Luz", "Bênção", "Ofuscar", "Juízo Solar"],
            ["Radiant Strike", "Sunbeam", "Flash", "Pillar of Light", "Blessing", "Dazzle", "Solar Judgment"],
            ["Golpe Radiante", "Rayo de Sol", "Destello", "Columna de Luz", "Bendición", "Deslumbrar", "Juicio Solar"]),
    "sombra": (["Mordida Sombria", "Projétil Umbral", "Onda de Breu", "Abismo", "Drenar Vida", "Maldição", "Eclipse Total"],
               ["Shadow Bite", "Umbral Shot", "Pitch Wave", "Abyss", "Life Drain", "Curse", "Total Eclipse"],
               ["Mordida Sombría", "Proyectil Umbrío", "Onda de Brea", "Abismo", "Drenar Vida", "Maldición", "Eclipse Total"]),
}
ABILITY_KINDS = ["strike", "bolt", "burst", "blast", "heal", "dot", "ult"]
ABILITY_TEMPLATE = {
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
    ("praia", L("Praia", "Beach", "Playa"), ["agua"], "islands", "water", "shell", ["#e8d9a0", "#dfcf92", "#efe2ae"], "#2f6fb5", ["#f4f0e0", "#d98c6a"]),
    ("lago", L("Lago", "Lake", "Lago"), ["agua"], "islands", "water", "grass", ["#6aa84f", "#5f9a46", "#76b55a"], "#2a5f9e", ["#9fd18a", "#e9e27a"]),
    ("recife", L("Recife", "Reef", "Arrecife"), ["agua"], "cave", "coral", "shell", ["#3f8fae", "#378299", "#4a9cbb"], "#c2566f", ["#f2a9b8", "#9be0e8"]),
    ("vulcao", L("Vulcão", "Volcano", "Volcán"), ["fogo"], "cave", "rock", "ember", ["#4a3a34", "#41332e", "#55443d"], "#2a1e1b", ["#ff7a2a", "#ffd04a"]),
    ("campo_lava", L("Campo de Lava", "Lava Field", "Campo de Lava"), ["fogo"], "islands", "lava", "ember", ["#5b4036", "#523a31", "#66493e"], "#e04a1a", ["#ffb03a", "#3a2a24"]),
    ("tundra", L("Tundra", "Tundra", "Tundra"), ["gelo"], "open", "ice", "snow", ["#e6f0f5", "#dbe8ef", "#f0f6f9"], "#8fbcd4", ["#ffffff", "#b5d7e6"]),
    ("caverna_congelada", L("Caverna Congelada", "Frozen Cave", "Cueva Helada"), ["gelo"], "cave", "ice", "crystal", ["#a9c9da", "#9dbfd1", "#b6d3e2"], "#5d8aa8", ["#e8fbff", "#7fd6e8"]),
    ("campo_grama", L("Campo de Grama", "Grassland", "Pradera"), ["planta"], "open", "tree", "flower", ["#5fa843", "#569c3c", "#68b34b"], "#2e6b23", ["#f5e050", "#e86a8a"]),
    ("floresta_densa", L("Floresta Densa", "Dense Forest", "Bosque Denso"), ["planta"], "cave", "tree", "mushroom", ["#3f7d33", "#38722d", "#47883a"], "#1f4a1a", ["#d94a3a", "#c9e07a"]),
    ("canion", L("Cânion", "Canyon", "Cañón"), ["terra"], "open", "rock", "pebble", ["#c98a52", "#bd7f49", "#d4955c"], "#7a4a28", ["#8a5a35", "#e0b07a"]),
    ("caverna_rochosa", L("Caverna Rochosa", "Rocky Cave", "Cueva Rocosa"), ["terra"], "cave", "rock", "pebble", ["#7b6a5a", "#706050", "#857463"], "#3d332a", ["#a89880", "#5a4a3a"]),
    ("planalto_tempestade", L("Planalto da Tempestade", "Storm Plateau", "Meseta Tormentosa"), ["eletrico"], "open", "rock", "spark", ["#5d6b4a", "#536042", "#677553"], "#2f3528", ["#f2d023", "#a8e0ff"]),
    ("ruinas_energizadas", L("Ruínas Energizadas", "Charged Ruins", "Ruinas Energizadas"), ["eletrico"], "rooms", "pillar", "spark", ["#6a6a7a", "#60606f", "#747485"], "#3a3a48", ["#f2d023", "#7af0ff"]),
    ("picos", L("Picos Montanhosos", "Mountain Peaks", "Picos Montañosos"), ["vento"], "open", "rock", "feather", ["#9aa59a", "#8f9a8f", "#a5b0a5"], "#5a625a", ["#ffffff", "#c9d6e0"]),
    ("plataformas_nuvens", L("Plataformas nas Nuvens", "Cloud Platforms", "Plataformas de Nubes"), ["vento"], "islands", "cloud", "feather", ["#e9eef5", "#dfe6ef", "#f2f5fa"], "#9fc3e8", ["#ffffff", "#ffe9a8"]),
    ("templo", L("Templo", "Temple", "Templo"), ["luz"], "rooms", "pillar", "crystal", ["#e8dcc0", "#ddd0b2", "#f0e6cc"], "#a89060", ["#fff1a8", "#ffffff"]),
    ("campo_cristais", L("Campo de Cristais", "Crystal Field", "Campo de Cristales"), ["luz"], "open", "crystal", "crystal", ["#d8e6c8", "#cddcbc", "#e2efd3"], "#f0e080", ["#fff8c8", "#bff0ff"]),
    ("floresta_sombria", L("Floresta Sombria", "Gloomy Forest", "Bosque Sombrío"), ["sombra"], "cave", "tree", "mushroom", ["#2f3a2c", "#293326", "#354232"], "#121a12", ["#8a5ad0", "#4a6a3a"]),
    ("cemiterio", L("Cemitério Antigo", "Ancient Graveyard", "Cementerio Antiguo"), ["sombra"], "rooms", "tomb", "bone", ["#4a4a40", "#424238", "#535348"], "#2a2a28", ["#d8d8c8", "#6a3d9a"]),
    ("pantano", L("Pântano", "Swamp", "Pantano"), ["agua", "planta"], "islands", "water", "mushroom", ["#5a6e3a", "#526534", "#627844"], "#2f4a3a", ["#9ab04a", "#c9a0d0"]),
    ("fontes_termais", L("Fontes Termais", "Hot Springs", "Aguas Termales"), ["agua", "fogo"], "islands", "water", "ember", ["#8a7a6a", "#807060", "#958575"], "#4aa0b0", ["#ffffff", "#ff9a5a"]),
    ("deserto_cinzas", L("Deserto de Cinzas", "Ash Desert", "Desierto de Ceniza"), ["fogo", "terra"], "open", "rock", "ember", ["#8a7060", "#806656", "#957a6a"], "#4a3a30", ["#ff7a2a", "#c0a080"]),
    ("geleira_rochosa", L("Geleira Rochosa", "Rocky Glacier", "Glaciar Rocoso"), ["gelo", "terra"], "cave", "ice", "pebble", ["#b8c4c8", "#adb9bd", "#c3cfd3"], "#6a7a80", ["#ffffff", "#8a7a6a"]),
    ("cordilheira_ventosa", L("Cordilheira Ventosa", "Windy Range", "Cordillera Ventosa"), ["vento", "terra", "eletrico"], "open", "rock", "feather", ["#8a9a8a", "#809080", "#95a595"], "#4a5a4a", ["#f2d023", "#ffffff"]),
    ("crepusculo", L("Vale do Crepúsculo", "Twilight Vale", "Valle del Crepúsculo"), ["luz", "sombra"], "rooms", "pillar", "crystal", ["#7a6a8a", "#706080", "#857595"], "#3a2a4a", ["#fff1a8", "#6a3d9a"]),
    ("brejo_sombrio", L("Brejo Sombrio", "Dark Marsh", "Ciénaga Sombría"), ["sombra", "planta"], "cave", "tree", "mushroom", ["#3a4a30", "#33422a", "#425236"], "#1a221a", ["#8a5ad0", "#9ab04a"]),
    ("geleira_eterea", L("Geleira Etérea", "Ethereal Glacier", "Glaciar Etéreo"), ["gelo", "vento"], "open", "ice", "feather", ["#dce8f0", "#d0dee8", "#e6f0f6"], "#8fbcd4", ["#ffffff", "#c9d6e0"]),
    ("tempestade_luminosa", L("Tempestade Luminosa", "Luminous Storm", "Tormenta Luminosa"), ["eletrico", "luz"], "open", "crystal", "spark", ["#c8c890", "#bebe86", "#d2d29a"], "#8a8a40", ["#f2d023", "#ffffff"]),
]

# Adjetivos de lugar: (pt masc, pt fem, en, es masc, es fem)
PLACE_ADJ = [
    ("Sereno", "Serena", "Serene", "Sereno", "Serena"), ("Antigo", "Antiga", "Ancient", "Antiguo", "Antigua"),
    ("Perdido", "Perdida", "Lost", "Perdido", "Perdida"), ("Sussurrante", "Sussurrante", "Whispering", "Susurrante", "Susurrante"),
    ("Dourado", "Dourada", "Golden", "Dorado", "Dorada"), ("Silencioso", "Silenciosa", "Silent", "Silencioso", "Silenciosa"),
    ("Selvagem", "Selvagem", "Wild", "Salvaje", "Salvaje"), ("Profundo", "Profunda", "Deep", "Profundo", "Profunda"),
    ("Esquecido", "Esquecida", "Forgotten", "Olvidado", "Olvidada"), ("Brilhante", "Brilhante", "Shining", "Brillante", "Brillante"),
    ("Tranquilo", "Tranquila", "Tranquil", "Tranquilo", "Tranquila"), ("Sombrio", "Sombria", "Gloomy", "Sombrío", "Sombría"),
    ("Encantado", "Encantada", "Enchanted", "Encantado", "Encantada"), ("Escondido", "Escondida", "Hidden", "Escondido", "Escondida"),
    ("Eterno", "Eterna", "Eternal", "Eterno", "Eterna"), ("Distante", "Distante", "Distant", "Lejano", "Lejana"),
    ("Rubro", "Rubra", "Crimson", "Carmesí", "Carmesí"), ("Azulado", "Azulada", "Bluish", "Azulado", "Azulada"),
    ("Velho", "Velha", "Old", "Viejo", "Vieja"), ("Alto", "Alta", "High", "Alto", "Alta"),
    ("Largo", "Larga", "Wide", "Ancho", "Ancha"), ("Bravio", "Bravia", "Untamed", "Bravío", "Bravía"),
]
# Substantivos de lugar por bioma: (pt, gênero pt, en, es, gênero es)
PLACE_NOUN = {
    "praia": [("Enseada", "f", "Cove", "Ensenada", "f"), ("Costa", "f", "Coast", "Costa", "f"), ("Baía", "f", "Bay", "Bahía", "f")],
    "lago": [("Lagoa", "f", "Lagoon", "Laguna", "f"), ("Margem", "f", "Shore", "Orilla", "f"), ("Açude", "m", "Pond", "Estanque", "m")],
    "recife": [("Recife", "m", "Reef", "Arrecife", "m"), ("Atol", "m", "Atoll", "Atolón", "m"), ("Banco de Coral", "m", "Coral Bank", "Banco de Coral", "m")],
    "vulcao": [("Cratera", "f", "Crater", "Cráter", "m"), ("Encosta", "f", "Slope", "Ladera", "f"), ("Chaminé", "f", "Vent", "Chimenea", "f")],
    "campo_lava": [("Planície", "f", "Plain", "Llanura", "f"), ("Fenda", "f", "Rift", "Grieta", "f"), ("Escarpa", "f", "Scarp", "Escarpa", "f")],
    "tundra": [("Estepe", "f", "Steppe", "Estepa", "f"), ("Planura", "f", "Flats", "Llanura", "f"), ("Campina", "f", "Meadow", "Campiña", "f")],
    "caverna_congelada": [("Gruta", "f", "Grotto", "Gruta", "f"), ("Caverna", "f", "Cavern", "Caverna", "f"), ("Galeria", "f", "Gallery", "Galería", "f")],
    "campo_grama": [("Pradaria", "f", "Prairie", "Pradera", "f"), ("Campina", "f", "Meadow", "Campiña", "f"), ("Colina", "f", "Hill", "Colina", "f")],
    "floresta_densa": [("Mata", "f", "Thicket", "Espesura", "f"), ("Floresta", "f", "Forest", "Selva", "f"), ("Clareira", "f", "Glade", "Claro", "m")],
    "canion": [("Desfiladeiro", "m", "Gorge", "Desfiladero", "m"), ("Garganta", "f", "Ravine", "Garganta", "f"), ("Ravina", "f", "Gully", "Barranco", "m")],
    "caverna_rochosa": [("Mina", "f", "Mine", "Mina", "f"), ("Caverna", "f", "Cave", "Cueva", "f"), ("Toca", "f", "Burrow", "Madriguera", "f")],
    "planalto_tempestade": [("Chapada", "f", "Mesa", "Mesa", "f"), ("Planalto", "m", "Plateau", "Meseta", "f"), ("Meseta", "f", "Highland", "Altiplano", "m")],
    "ruinas_energizadas": [("Ruína", "f", "Ruin", "Ruina", "f"), ("Usina", "f", "Powerworks", "Central", "f"), ("Cidadela", "f", "Citadel", "Ciudadela", "f")],
    "picos": [("Pico", "m", "Peak", "Pico", "m"), ("Serra", "f", "Ridge", "Sierra", "f"), ("Crista", "f", "Crest", "Cresta", "f")],
    "plataformas_nuvens": [("Ilha Celeste", "f", "Sky Island", "Isla Celeste", "f"), ("Plataforma", "f", "Platform", "Plataforma", "f"), ("Ninho", "m", "Nest", "Nido", "m")],
    "templo": [("Santuário", "m", "Sanctuary", "Santuario", "m"), ("Templo", "m", "Temple", "Templo", "m"), ("Capela", "f", "Chapel", "Capilla", "f")],
    "campo_cristais": [("Jazida", "f", "Lode", "Yacimiento", "m"), ("Campo", "m", "Field", "Campo", "m"), ("Vale", "m", "Vale", "Valle", "m")],
    "floresta_sombria": [("Floresta", "f", "Woods", "Bosque", "m"), ("Bosque", "m", "Grove", "Arboleda", "f"), ("Mata", "f", "Wildwood", "Espesura", "f")],
    "cemiterio": [("Necrópole", "f", "Necropolis", "Necrópolis", "f"), ("Cripta", "f", "Crypt", "Cripta", "f"), ("Campo-Santo", "m", "Churchyard", "Camposanto", "m")],
    "pantano": [("Brejo", "m", "Marsh", "Ciénaga", "f"), ("Charco", "m", "Bog", "Charca", "f"), ("Pântano", "m", "Swamp", "Pantano", "m")],
    "fontes_termais": [("Fonte", "f", "Spring", "Fuente", "f"), ("Nascente", "f", "Source", "Manantial", "m"), ("Gêiser", "m", "Geyser", "Géiser", "m")],
    "deserto_cinzas": [("Deserto", "m", "Desert", "Desierto", "m"), ("Ermo", "m", "Wastes", "Páramo", "m"), ("Planície", "f", "Plain", "Llanura", "f")],
    "geleira_rochosa": [("Geleira", "f", "Glacier", "Glaciar", "m"), ("Morena", "f", "Moraine", "Morrena", "f"), ("Fiorde", "m", "Fjord", "Fiordo", "m")],
    "cordilheira_ventosa": [("Cordilheira", "f", "Range", "Cordillera", "f"), ("Passo", "m", "Pass", "Paso", "m"), ("Desfiladeiro", "m", "Defile", "Desfiladero", "m")],
    "crepusculo": [("Vale", "m", "Vale", "Valle", "m"), ("Pátio", "m", "Courtyard", "Patio", "m"), ("Claustro", "m", "Cloister", "Claustro", "m")],
    "brejo_sombrio": [("Brejo", "m", "Fen", "Ciénaga", "f"), ("Lodaçal", "m", "Mire", "Lodazal", "m"), ("Charco", "m", "Bog", "Charca", "f")],
    "geleira_eterea": [("Geleira", "f", "Glacier", "Glaciar", "m"), ("Campo", "m", "Snowfield", "Campo", "m"), ("Cume", "m", "Summit", "Cumbre", "f")],
    "tempestade_luminosa": [("Planalto", "m", "Plateau", "Meseta", "f"), ("Campo", "m", "Field", "Campo", "m"), ("Chapada", "f", "Mesa", "Mesa", "f")],
}

# Itens: (id, nome, atributo, [substantivos por tier PT (gênero)], [EN], [ES (gênero)])
SLOTS = [
    ("amuleto", L("Amuleto", "Amulet", "Amuleto"), "hp",
     [("Pingente", "m"), ("Amuleto", "m"), ("Medalhão", "m"), ("Talismã", "m"), ("Colar", "m"), ("Gargantilha", "f"), ("Insígnia", "f"), ("Relicário", "m"), ("Coroa-Pingente", "f")],
     ["Pendant", "Amulet", "Medallion", "Talisman", "Necklace", "Choker", "Insignia", "Reliquary", "Crown Pendant"],
     [("Colgante", "m"), ("Amuleto", "m"), ("Medallón", "m"), ("Talismán", "m"), ("Collar", "m"), ("Gargantilla", "f"), ("Insignia", "f"), ("Relicario", "m"), ("Colgante Real", "m")]),
    ("garra", L("Garra", "Claw", "Garra"), "atk",
     [("Garra", "f"), ("Presa", "f"), ("Ferrão", "m"), ("Lâmina", "f"), ("Gadanha", "f"), ("Navalha", "f"), ("Dente-Rei", "m"), ("Ceifadora", "f"), ("Garra Ancestral", "f")],
     ["Claw", "Fang", "Stinger", "Blade", "Scythe", "Razor", "King Tooth", "Reaper", "Ancient Claw"],
     [("Garra", "f"), ("Colmillo", "m"), ("Aguijón", "m"), ("Hoja", "f"), ("Guadaña", "f"), ("Navaja", "f"), ("Diente Real", "m"), ("Segadora", "f"), ("Garra Ancestral", "f")]),
    ("armadura", L("Armadura", "Armor", "Armadura"), "def",
     [("Couraça", "f"), ("Escama", "f"), ("Carapaça", "f"), ("Malha", "f"), ("Égide", "f"), ("Couro", "m"), ("Bastião", "m"), ("Fortaleza", "f"), ("Manto Primevo", "m")],
     ["Cuirass", "Scale", "Carapace", "Mail", "Aegis", "Hide", "Bastion", "Fortress", "Primeval Mantle"],
     [("Coraza", "f"), ("Escama", "f"), ("Caparazón", "m"), ("Malla", "f"), ("Égida", "f"), ("Cuero", "m"), ("Bastión", "m"), ("Fortaleza", "f"), ("Manto Primigenio", "m")]),
    ("reliquia", L("Relíquia", "Relic", "Reliquia"), "spd",
     [("Seixo", "m"), ("Orbe", "m"), ("Totem", "m"), ("Ídolo", "m"), ("Cristal", "m"), ("Fragmento", "m"), ("Núcleo", "m"), ("Coração", "m"), ("Essência Viva", "f")],
     ["Pebble", "Orb", "Totem", "Idol", "Crystal", "Shard", "Core", "Heart", "Living Essence"],
     [("Guijarro", "m"), ("Orbe", "m"), ("Tótem", "m"), ("Ídolo", "m"), ("Cristal", "m"), ("Fragmento", "m"), ("Núcleo", "m"), ("Corazón", "m"), ("Esencia Viva", "f")]),
]
# adjetivo temático por tipo: (pt m, pt f, en, es m, es f)
TYPE_ADJ = {
    "agua": ("Coralino", "Coralina", "Coral", "Coralino", "Coralina"), "fogo": ("Ígneo", "Ígnea", "Igneous", "Ígneo", "Ígnea"),
    "gelo": ("Glacial", "Glacial", "Glacial", "Glacial", "Glacial"), "planta": ("Silvestre", "Silvestre", "Wild", "Silvestre", "Silvestre"),
    "terra": ("Rochoso", "Rochosa", "Rocky", "Rocoso", "Rocosa"), "eletrico": ("Voltaico", "Voltaica", "Voltaic", "Voltaico", "Voltaica"),
    "vento": ("Etéreo", "Etérea", "Ethereal", "Etéreo", "Etérea"), "luz": ("Radiante", "Radiante", "Radiant", "Radiante", "Radiante"),
    "sombra": ("Umbral", "Umbral", "Umbral", "Umbrío", "Umbría"),
}
TIERS = [
    {"tier": 1, "level": 1, "world2": False}, {"tier": 2, "level": 12, "world2": False}, {"tier": 3, "level": 25, "world2": False},
    {"tier": 4, "level": 40, "world2": False}, {"tier": 5, "level": 60, "world2": False}, {"tier": 6, "level": 80, "world2": False},
    {"tier": 7, "level": 120, "world2": True}, {"tier": 8, "level": 170, "world2": True}, {"tier": 9, "level": 230, "world2": True},
]


def wjson(name, obj):
    path = os.path.join(DATA, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
    print("escrito", path)


def gen_types():
    wjson("types.json", {
        "_comentario": "Ciclo: cada tipo é forte contra o próximo da lista e fraco contra o anterior. Reordene 'types' para mudar o ciclo.",
        "strong_mult": 1.5, "weak_mult": 0.67, "neutral_mult": 1.0,
        "types": [{"id": t[0], "name": t[1], "color": t[2]} for t in TYPES],
    })


def gen_abilities():
    abilities = {}
    for t in TYPE_IDS:
        pt, en, es = ABILITY_NAMES[t]
        for i, kind in enumerate(ABILITY_KINDS):
            a = dict(ABILITY_TEMPLATE[kind])
            a.update({"id": "%s_%s" % (t, kind), "name": L(pt[i], en[i], es[i]), "type": t, "kind": kind})
            abilities[a["id"]] = a
    wjson("abilities.json", {"abilities": abilities})


def gen_families():
    fams = []
    for t in TYPE_IDS:
        for fi, (names, shape, style, features, concept, starter) in enumerate(FAMILIES[t]):
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
                desc = {}
                for lg in LANGS:
                    x = STAGE_EXTRA[lg][s - 1][style] if s > 0 else ""
                    sp = SPECIES[fid][LANGS.index(lg)]
                    desc[lg] = STAGE_DESC[lg][s].format(c=concept[lg], x=x, sp=sp)
                stages.append({"form_id": "%s_%d" % (fid, s + 1), "name": names[s], "stage": s + 1, "desc": desc,
                               "abilities": ["%s_%s" % (t, k) for k in STYLE_ABILITIES[style][s]]})
            fams.append({
                "id": fid, "type": t, "shape": shape, "style": style, "features": features, "starter": starter,
                "evo_levels": [16, 35], "essence_mult": 1.5 if starter else round(rnd.uniform(0.9, 1.2), 2),
                "hue_shift": round((fi - 2) * 0.03, 3), "base": base, "stages": stages,
            })
    wjson("families.json", {
        "_comentario": "45 famílias (animal + elemento), 3 estágios cada. 'base' = atributos no nível 1 do Filhote. 'features' define o desenho placeholder.",
        "families": fams,
    })
    return fams


def gen_biomes():
    out = []
    for b in BIOMES:
        out.append({"id": b[0], "name": b[1], "types": b[2], "gen": b[3], "wall_style": b[4], "deco_style": b[5],
                    "floor": b[6], "wall": b[7], "deco": b[8]})
    wjson("biomes.json", {"_comentario": "Paletas e estilos de geração por bioma. Mundo 2 aplica 'corruption' do config.json.", "biomes": out})


def sub_biomes(t):
    return [b[0] for b in BIOMES if b[2] == [t]]


def drop_bases(types, level, rnd):
    tier = 1
    for tr in TIERS:
        if tr["level"] <= level and not tr["world2"]:
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
    for _ in range(300):
        noun = rnd.choice(PLACE_NOUN[biome])
        adj = rnd.choice(PLACE_ADJ)
        pt = "%s %s" % (noun[0], adj[0] if noun[1] == "m" else adj[1])
        if pt in used:
            continue
        used.add(pt)
        en = "%s %s" % (adj[2], noun[2])
        es = "%s %s" % (noun[3], adj[3] if noun[4] == "m" else adj[4])
        return L(pt, en, es)
    return L(biome, biome, biome)


def requires_challenge(level):
    c = ((level - 1) // 10) * 10
    return c if 10 <= c <= 80 else 0


def make_hunt(hid, name, lvl, unlock, biome, types, monsters, density, respawn, size, rnd, category):
    return {
        "id": hid, "name": name, "world": 1, "category": category, "level": lvl, "unlock_level": unlock,
        "requires_challenge": requires_challenge(lvl), "biome": biome, "types": types, "monsters": monsters,
        "density": density, "respawn": respawn, "map_size": [size, size], "seed": rnd.randint(1, 2**30),
        "recruit": True, "recruit_mult": 1.0, "xp_mult": 1.0, "gold_mult": 1.0, "drops": drop_bases(types, lvl, rnd),
    }


def gen_hunts(fams):
    rnd = random.Random(424242)
    used = set()
    hunts = []
    by_type = {t: [f for f in fams if f["type"] == t] for t in TYPE_IDS}
    groups = [(["agua", "planta", "vento"], 1, [1, 2, 3, 4, 5]), (["fogo", "terra", "luz"], 6, [6, 7, 8, 9, 10]),
              (["gelo", "eletrico", "sombra"], 12, [12, 13, 14, 15, 15])]
    for types, unlock, levels in groups:
        for t in types:
            for fi, f in enumerate(by_type[t]):
                biome = sub_biomes(t)[fi % len(sub_biomes(t))]
                hunts.append(make_hunt("w1_s1_%s" % f["id"], place_name(biome, rnd, used), levels[fi], unlock, biome,
                                       [t], [{"form": f["stages"][0]["form_id"], "weight": 1}], 14, 9.0, 40, rnd, "filhote"))
    order = [by_type[t][fi] for fi in range(5) for t in TYPE_IDS]
    for i, f in enumerate(order):
        lvl = 16 + (i * 19) // 45
        t = f["type"]
        biome = sub_biomes(t)[i % len(sub_biomes(t))]
        hunts.append(make_hunt("w1_s2_%s" % f["id"], place_name(biome, rnd, used), lvl, max(16, lvl - 2), biome,
                               [t], [{"form": f["stages"][1]["form_id"], "weight": 1}], 16, 10.0, 44, rnd, "adolescente"))
    for i, f in enumerate(order):
        lvl = 35 + (i * 46) // 45
        t = f["type"]
        biome = sub_biomes(t)[(i + 1) % len(sub_biomes(t))]
        hunts.append(make_hunt("w1_s3_%s" % f["id"], place_name(biome, rnd, used), lvl, max(35, lvl - 3), biome,
                               [t], [{"form": f["stages"][2]["form_id"], "weight": 1}], 18, 10.0, 48, rnd, "adulto"))
    mixed = [("pantano", ["agua", "planta"], 1, 20), ("fontes_termais", ["agua", "fogo"], 1, 24), ("deserto_cinzas", ["fogo", "terra"], 1, 28),
             ("geleira_rochosa", ["gelo", "terra"], 1, 32), ("brejo_sombrio", ["sombra", "planta"], 2, 42), ("crepusculo", ["luz", "sombra"], 2, 52),
             ("geleira_eterea", ["gelo", "vento"], 2, 62), ("tempestade_luminosa", ["eletrico", "luz"], 2, 70),
             ("cordilheira_ventosa", ["vento", "terra", "eletrico"], 2, 78)]
    for biome, types, stage_idx, lvl in mixed:
        monsters = []
        for t in types:
            for f in rnd.sample(by_type[t], 2):
                monsters.append({"form": f["stages"][stage_idx]["form_id"], "weight": 1})
        unlock = max(16 if stage_idx == 1 else 35, lvl - 3)
        hunts.append(make_hunt("w1_mix_%s" % biome, place_name(biome, rnd, used), lvl, unlock, biome, types, monsters, 20, 9.0, 52, rnd, "mista"))
    hunts.sort(key=lambda h: (h["level"], h["id"]))
    wjson("hunts_world1.json", {
        "_comentario": "Hunts do Mundo 1. density = monstros simultâneos; respawn em segundos; map_size em tiles. Mundo 2 é gerado pelo config.json (world2).",
        "hunts": hunts,
    })


BOSSES = [
    (10, L("Marolontra, Rainha das Ondas", "Marolontra, Queen of Waves", "Marolontra, Reina de las Olas"), "agua_1_2", "praia", {"summon": {"form": "agua_2_1", "every": 12, "count": 2}}),
    (20, L("Raposbrasa, a Incendiária", "Raposbrasa the Firestarter", "Raposbrasa, la Incendiaria"), "fogo_1_2", "vulcao", {"aoe": {"every": 9, "count": 3, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.6}}),
    (30, L("Cervilha Anciã", "Elder Cervilha", "Cervilha Anciana"), "planta_1_2", "floresta_densa", {"summon": {"form": "planta_4_2", "every": 12, "count": 2}, "aoe": {"every": 10, "count": 2, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.6}}),
    (40, L("Tatuzólito Desperto", "Awakened Tatuzólito", "Tatuzólito Despierto"), "terra_1_3", "caverna_rochosa", {"aoe": {"every": 8, "count": 4, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.5}}),
    (50, L("Leoparvalanche Branco", "White Leoparvalanche", "Leoparvalanche Blanco"), "gelo_2_3", "caverna_congelada", {"summon": {"form": "gelo_1_2", "every": 12, "count": 2}}),
    (60, L("Carneiraio, Senhor da Tempestade", "Carneiraio, Storm Lord", "Carneiraio, Señor de la Tormenta"), "eletrico_1_3", "ruinas_energizadas", {"summon": {"form": "eletrico_3_2", "every": 12, "count": 2}, "aoe": {"every": 8, "count": 3, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.4}}),
    (70, L("Lebreventania Ancestral", "Ancestral Lebreventania", "Lebreventania Ancestral"), "vento_1_3", "plataformas_nuvens", {"aoe": {"every": 7, "count": 4, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.4}}),
    (80, L("Alvorcorno, Juiz da Aurora", "Alvorcorno, Judge of Dawn", "Alvorcorno, Juez del Alba"), "luz_1_3", "templo", {"summon": {"form": "luz_3_2", "every": 12, "count": 2}, "aoe": {"every": 7, "count": 4, "radius": 2, "dmg_pct": 0.15, "telegraph": 1.5}}),
    (90, L("Eclipsilobo Primordial", "Primordial Eclipsilobo", "Eclipsilobo Primordial"), "sombra_1_3", "cemiterio", {"summon": {"form": "sombra_2_3", "every": 12, "count": 2}, "aoe": {"every": 6, "count": 4, "radius": 1, "dmg_pct": 0.15, "telegraph": 1.3}}),
]
PHASE_SAY = L("Fase 2: o chefe se enfurece!", "Phase 2: the boss is enraged!", "¡Fase 2: el jefe se enfurece!")

# Chefes de Mundo: provas de força que liberam o mundo seguinte. Não são recrutáveis.
WORLD_BOSSES = [
    (110, L("Gorilamonte, Guardião do Mundo 1", "Gorilamonte, Guardian of World 1", "Gorilamonte, Guardián del Mundo 1"), "terra_5_3", "caverna_rochosa", "world2",
     {"summon": {"form": "terra_3_3", "every": 14, "count": 2, "level_offset": 6}, "aoe": {"every": 7, "count": 5, "radius": 1, "dmg_pct": 0.14, "telegraph": 1.4}}),
    (210, L("Krakenoite, Guardião do Abismo", "Krakenoite, Guardian of the Abyss", "Krakenoite, Guardián del Abismo"), "sombra_5_3", "brejo_sombrio", "world3",
     {"summon": {"form": "sombra_4_3", "every": 13, "count": 2, "level_offset": 6}, "aoe": {"every": 6, "count": 6, "radius": 1, "dmg_pct": 0.14, "telegraph": 1.3}}),
]


def gen_challenges():
    prev = {}
    path = os.path.join(DATA, "challenges.json")
    if os.path.exists(path):
        for c in json.load(open(path, encoding="utf-8")).get("challenges", []):
            prev[c["id"]] = c
    out = []
    for lvl, name, form, biome, mech in BOSSES:
        t = form.split("_")[0]
        reward_rarity = "raro" if lvl <= 30 else ("epico" if lvl <= 60 else "lendario")
        c = {
            "id": "c%d" % lvl, "level": lvl, "name": name, "boss_form": form, "type": t, "biome": biome,
            "boss_level": lvl + 2, "hp_mult": 30.0, "atk_mult": 0.5, "def_mult": 1.2, "scale": 1.6,
            "phases": [{"hp_below": 0.5, "atk_mult": 1.3, "spd_mult": 1.2, "say": PHASE_SAY}],
            "mechanics": mech, "time_limit": 240,
            "rewards": {"gold": 500 * lvl, "essence": {t: 40 * lvl // 10}, "item_rarity": reward_rarity},
            "unlocks": "", "map_size": [26, 26], "seed": 1000 + lvl,
        }
        old = prev.get(c["id"])
        if old:
            for k in ("hp_mult", "atk_mult", "def_mult", "mechanics"):
                if k in old:
                    c[k] = old[k]
        out.append(c)
    for lvl, name, form, biome, unlock, mech in WORLD_BOSSES:
        t = form.split("_")[0]
        c = {
            "id": "wb%d" % lvl, "level": lvl, "name": name, "boss_form": form, "type": t, "biome": biome,
            "boss_level": lvl + 3, "hp_mult": 60.0, "atk_mult": 0.6, "def_mult": 1.1, "scale": 2.1, "world_boss": True,
            "phases": [{"hp_below": 0.5, "atk_mult": 1.3, "spd_mult": 1.2, "say": PHASE_SAY}],
            "mechanics": mech, "time_limit": 300, "min_fighters": 2 if lvl == 110 else 3,
            "rewards": {"gold": 1500 * lvl, "essence": {t: 80 * lvl // 10}, "item_rarity": "lendario"},
            "unlocks": unlock, "map_size": [30, 30], "seed": 5000 + lvl,
        }
        old = prev.get(c["id"])
        if old:
            for k in ("hp_mult", "atk_mult", "def_mult", "mechanics"):
                if k in old:
                    c[k] = old[k]
        out.append(c)
    wjson("challenges.json", {"_comentario": "Desafios (bosses). Para desafios acima de 90, inclua novas entradas aqui.",
                              "fail_cooldown_seconds": 60, "challenges": out})


def gen_items():
    bases = {}
    for tr in TIERS:
        for t in TYPE_IDS:
            for sid, sname, stat, pt_nouns, en_nouns, es_nouns in SLOTS:
                i = tr["tier"] - 1
                a = TYPE_ADJ[t]
                pt = "%s %s" % (pt_nouns[i][0], a[0] if pt_nouns[i][1] == "m" else a[1])
                en = "%s %s" % (a[2], en_nouns[i])
                es = "%s %s" % (es_nouns[i][0], a[3] if es_nouns[i][1] == "m" else a[4])
                bid = "%s_%s_t%d" % (sid, t, tr["tier"])
                bases[bid] = {"id": bid, "name": L(pt, en, es), "slot": sid, "type": t, "tier": tr["tier"],
                              "level": tr["level"], "world2_only": tr["world2"], "main_stat": stat}
    affixes = [
        {"id": "hp_pct", "stat": "hp_pct", "min": 3, "max": 10}, {"id": "atk_pct", "stat": "atk_pct", "min": 3, "max": 10},
        {"id": "def_pct", "stat": "def_pct", "min": 3, "max": 10}, {"id": "spd_pct", "stat": "spd_pct", "min": 2, "max": 6},
        {"id": "crit", "stat": "crit", "min": 1, "max": 5}, {"id": "lifesteal", "stat": "lifesteal", "min": 1, "max": 4},
        {"id": "cdr", "stat": "cdr", "min": 2, "max": 8}, {"id": "xp_pct", "stat": "xp_pct", "min": 1, "max": 5},
        {"id": "gold_pct", "stat": "gold_pct", "min": 2, "max": 8},
        {"id": "type_dmg", "stat": "type_dmg", "min": 4, "max": 12, "per_type": True},
    ]
    wjson("items.json", {
        "_comentario": "Bases de itens (slot x tipo x tier) e afixos. Valores base dos atributos por slot em config.json (items).",
        "slots": [{"id": s[0], "name": s[1], "main_stat": s[2]} for s in SLOTS],
        "tiers": TIERS, "bases": bases, "affixes": affixes,
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
