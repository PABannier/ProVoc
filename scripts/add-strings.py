#!/usr/bin/env python3
"""Adds the strings introduced by the arm64 revival to every Localizable.strings.

The six files have different encodings (UTF-8, UTF-8 with BOM, UTF-16 BE) and line
endings (LF, CR); each file keeps its own. Running the script again changes nothing.
"""
import codecs, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Resources')
LANGUAGES = ['English', 'French', 'German', 'Italian', 'Spanish', 'Danish']

# key: (English, French, German, Italian, Spanish, Danish)
STRINGS = {
    'iPod Obsolete Title': (
        'Notes can no longer be sent to an iPod',
        'Les notes ne peuvent plus être envoyées sur un iPod',
        'Notizen können nicht mehr an einen iPod gesendet werden',
        'Non è più possibile inviare note a un iPod',
        'Ya no se pueden enviar notas a un iPod',
        'Noter kan ikke længere sendes til en iPod'),
    'iPod Obsolete Message': (
        'iPods with the Notes feature are no longer supported by macOS. You can export your vocabulary to a file instead.',
        'Les iPod dotés de la fonction Notes ne sont plus pris en charge par macOS. Vous pouvez exporter votre vocabulaire dans un fichier à la place.',
        'iPods mit der Notizen-Funktion werden von macOS nicht mehr unterstützt. Sie können Ihr Vokabular stattdessen in eine Datei exportieren.',
        'Gli iPod con la funzione Note non sono più supportati da macOS. Puoi invece esportare il vocabolario in un file.',
        'macOS ya no admite los iPod con la función Notas. En su lugar puede exportar su vocabulario a un archivo.',
        'iPods med Noter-funktionen understøttes ikke længere af macOS. Du kan i stedet eksportere dit ordforråd til et arkiv.'),
    'iPod Obsolete Export Button': ('Export…', 'Exporter…', 'Exportieren…', 'Esporta…', 'Exportar…', 'Eksporter…'),
    'iPod Obsolete Cancel Button': ('Cancel', 'Annuler', 'Abbrechen', 'Annulla', 'Cancelar', 'Annuller'),
    'Updates Obsolete Title': (
        'ProVoc can no longer check for updates',
        'ProVoc ne peut plus rechercher de mises à jour',
        'ProVoc kann nicht mehr nach Updates suchen',
        'ProVoc non può più cercare aggiornamenti',
        'ProVoc ya no puede buscar actualizaciones',
        'ProVoc kan ikke længere søge efter opdateringer'),
    'Updates Obsolete Message (v=%@)': (
        'Arizona Software no longer publishes ProVoc. This is version %@, rebuilt from its source code for current Macs.',
        'Arizona Software ne publie plus ProVoc. Ceci est la version %@, recompilée à partir de son code source pour les Mac actuels.',
        'Arizona Software veröffentlicht ProVoc nicht mehr. Dies ist Version %@, aus dem Quellcode für aktuelle Macs neu gebaut.',
        'Arizona Software non pubblica più ProVoc. Questa è la versione %@, ricompilata dal codice sorgente per i Mac attuali.',
        'Arizona Software ya no publica ProVoc. Esta es la versión %@, recompilada a partir de su código fuente para los Mac actuales.',
        'Arizona Software udgiver ikke længere ProVoc. Dette er version %@, genopbygget fra kildekoden til nutidens Mac-computere.'),
    'Web Site Gone Title': (
        'The Arizona Software web site no longer exists',
        'Le site web d’Arizona Software n’existe plus',
        'Die Website von Arizona Software existiert nicht mehr',
        'Il sito web di Arizona Software non esiste più',
        'El sitio web de Arizona Software ya no existe',
        'Arizona Softwares websted findes ikke længere'),
    'Web Site Gone Homepage Message': (
        'ProVoc was published by Arizona Software until 2008. Its source code is public; this copy was rebuilt from it.',
        'ProVoc a été publié par Arizona Software jusqu’en 2008. Son code source est public ; cette copie a été recompilée à partir de celui-ci.',
        'ProVoc wurde bis 2008 von Arizona Software veröffentlicht. Der Quellcode ist öffentlich; diese Kopie wurde daraus neu gebaut.',
        'ProVoc è stato pubblicato da Arizona Software fino al 2008. Il codice sorgente è pubblico; questa copia è stata ricompilata da esso.',
        'ProVoc fue publicado por Arizona Software hasta 2008. Su código fuente es público; esta copia se ha recompilado a partir de él.',
        'ProVoc blev udgivet af Arizona Software indtil 2008. Kildekoden er offentlig; denne kopi er genopbygget fra den.'),
    'Web Site Gone Feedback Message': (
        'Nobody at Arizona Software receives bug reports or feedback any more.',
        'Plus personne chez Arizona Software ne reçoit les rapports de bogue ni les commentaires.',
        'Bei Arizona Software nimmt niemand mehr Fehlerberichte oder Rückmeldungen entgegen.',
        'Nessuno in Arizona Software riceve più segnalazioni di errori o commenti.',
        'Ya nadie en Arizona Software recibe informes de errores ni comentarios.',
        'Ingen hos Arizona Software modtager længere fejlrapporter eller kommentarer.'),
    'Web Site Gone Vocabulary Message': (
        'The vocabulary library was hosted on that site. You can still import vocabulary from text files with File > Import…',
        'La bibliothèque de vocabulaires était hébergée sur ce site. Vous pouvez toujours importer du vocabulaire depuis des fichiers texte avec Fichier > Importer…',
        'Die Vokabelbibliothek lag auf dieser Website. Sie können weiterhin Vokabeln aus Textdateien importieren: Ablage > Importieren…',
        'La libreria dei vocabolari era ospitata su quel sito. Puoi ancora importare vocaboli da file di testo con File > Importa…',
        'La biblioteca de vocabularios estaba alojada en ese sitio. Todavía puede importar vocabulario desde archivos de texto con Archivo > Importar…',
        'Ordforrådsbiblioteket lå på det websted. Du kan stadig importere ordforråd fra tekstarkiver med Arkiv > Importer…'),
    'Help Window Title': ('ProVoc Help', 'Aide ProVoc', 'ProVoc-Hilfe', 'Aiuto ProVoc', 'Ayuda de ProVoc', 'ProVoc-hjælp'),
    'Movie Unsupported Format Message': (
        'This movie cannot be played: its format is not supported by this version of macOS.',
        'Cette séquence ne peut pas être lue : son format n’est pas pris en charge par cette version de macOS.',
        'Dieser Film kann nicht abgespielt werden: Sein Format wird von dieser macOS-Version nicht unterstützt.',
        'Questo filmato non può essere riprodotto: il suo formato non è supportato da questa versione di macOS.',
        'Esta película no se puede reproducir: su formato no es compatible con esta versión de macOS.',
        'Denne film kan ikke afspilles: dens format understøttes ikke af denne version af macOS.'),
    'System Font Caption': ('System Font', 'Police système', 'Systemschrift', 'Font di sistema', 'Tipo de letra del sistema', 'Systemskrift'),
}

def escape(text):
    return text.replace('\\', '\\\\').replace('"', '\\"')

def main():
    changed = False
    for index, language in enumerate(LANGUAGES):
        path = os.path.join(ROOT, language + '.lproj', 'Localizable.strings')
        raw = open(path, 'rb').read()
        if raw.startswith(codecs.BOM_UTF16_BE):
            encoding, bom, text = 'utf-16-be', codecs.BOM_UTF16_BE, raw[2:].decode('utf-16-be')
        elif raw.startswith(codecs.BOM_UTF16_LE):
            encoding, bom, text = 'utf-16-le', codecs.BOM_UTF16_LE, raw[2:].decode('utf-16-le')
        elif raw.startswith(codecs.BOM_UTF8):
            encoding, bom, text = 'utf-8', codecs.BOM_UTF8, raw[3:].decode('utf-8')
        else:
            encoding, bom, text = 'utf-8', b'', raw.decode('utf-8')
        newline = '\r\n' if '\r\n' in text else ('\r' if '\r' in text else '\n')
        lines = text.split(newline)
        additions = []
        for key, translations in STRINGS.items():
            line = '"%s" = "%s";' % (escape(key), escape(translations[index]))
            pattern = re.compile(r'"%s"\s*=\s*".*";\s*$' % re.escape(escape(key)))
            found = [i for i, existing in enumerate(lines) if pattern.match(existing)]
            if found:
                lines[found[0]] = line
            else:
                additions.append(line)
        if additions:
            while lines and lines[-1] == '':
                lines.pop()
            lines += ['', '/* Added for the arm64 revival (scripts/add-strings.py) */'] + additions + ['']
        text = newline.join(lines)
        data = bom + text.encode(encoding)
        if data != raw:
            open(path, 'wb').write(data)
            changed = True
            print('updated', path)
    return 0

if __name__ == '__main__':
    sys.exit(main())
