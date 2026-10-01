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
    'Media Menu Title': ('Media', 'Médias', 'Medien', 'Media', 'Multimedia', 'Medier'),
    'Media Menu Play First Audio': ('Play Question / Source Audio', 'Lire l’audio de la question / source', 'Audio der Frage / Quelle abspielen', 'Riproduci audio della domanda / origine', 'Reproducir audio de la pregunta / origen', 'Afspil spørgsmålets / kildens lyd'),
    'Media Menu Play Second Audio': ('Play Answer / Target Audio', 'Lire l’audio de la réponse / cible', 'Audio der Antwort / des Ziels abspielen', 'Riproduci audio della risposta / destinazione', 'Reproducir audio de la respuesta / destino', 'Afspil svarets / målets lyd'),
    'Media Menu Show Image': ('Show Image in Full Size', 'Afficher l’image en taille réelle', 'Bild in voller Größe zeigen', 'Mostra immagine a grandezza naturale', 'Mostrar imagen a tamaño completo', 'Vis billede i fuld størrelse'),
    'Media Menu Play Movie': ('Play Movie', 'Lire la séquence', 'Film abspielen', 'Riproduci filmato', 'Reproducir película', 'Afspil film'),
    'Media Menu Play Movie Full Size': ('Play Movie in Full Size', 'Lire la séquence en taille réelle', 'Film in voller Größe abspielen', 'Riproduci filmato a grandezza naturale', 'Reproducir película a tamaño completo', 'Afspil film i fuld størrelse'),
    'Media Menu Record First Audio': ('Record Source Audio…', 'Enregistrer l’audio de la source…', 'Audio der Quelle aufnehmen…', 'Registra audio di origine…', 'Grabar audio de origen…', 'Optag kildens lyd…'),
    'Media Menu Record Second Audio': ('Record Target Audio…', 'Enregistrer l’audio de la cible…', 'Audio des Ziels aufnehmen…', 'Registra audio di destinazione…', 'Grabar audio de destino…', 'Optag målets lyd…'),
    'Media Menu Capture Image': ('Capture Image…', 'Capturer une image…', 'Bild aufnehmen…', 'Cattura immagine…', 'Capturar imagen…', 'Optag billede…'),
    'Media Menu Record Movie': ('Record Movie…', 'Enregistrer une séquence…', 'Film aufnehmen…', 'Registra filmato…', 'Grabar película…', 'Optag film…'),
    'Recorder Window Title': ('Record Audio', 'Enregistrement audio', 'Audio aufnehmen', 'Registra audio', 'Grabar audio', 'Optag lyd'),
    'Recorder Record Button': ('Record', 'Enregistrer', 'Aufnehmen', 'Registra', 'Grabar', 'Optag'),
    'Recorder Stop Button': ('Stop', 'Arrêter', 'Stopp', 'Stop', 'Detener', 'Stop'),
    'Recorder Play Button': ('Play', 'Lire', 'Abspielen', 'Riproduci', 'Reproducir', 'Afspil'),
    'Recorder OK Button': ('OK', 'OK', 'OK', 'OK', 'Aceptar', 'OK'),
    'Recorder Cancel Button': ('Cancel', 'Annuler', 'Abbrechen', 'Annulla', 'Cancelar', 'Annuller'),
    'Recorder Ready Status': ('Press Record (or the space bar) to start.', 'Appuyez sur Enregistrer (ou sur la barre d’espace) pour commencer.', 'Zum Starten „Aufnehmen“ (oder die Leertaste) drücken.', 'Premi Registra (o la barra spaziatrice) per iniziare.', 'Pulse Grabar (o la barra espaciadora) para empezar.', 'Tryk på Optag (eller mellemrumstasten) for at begynde.'),
    'Recorder Recording Status (%.1f s)': ('Recording… %.1f s — press Return when done.', 'Enregistrement… %.1f s — appuyez sur Retour pour terminer.', 'Aufnahme… %.1f s — zum Beenden die Eingabetaste drücken.', 'Registrazione… %.1f s — premi Invio per terminare.', 'Grabando… %.1f s — pulse Retorno para terminar.', 'Optager… %.1f s — tryk på Retur for at afslutte.'),
    'Recorder Recorded Status': ('Recorded. Press Return to keep it.', 'Enregistré. Appuyez sur Retour pour le conserver.', 'Aufgenommen. Zum Übernehmen die Eingabetaste drücken.', 'Registrato. Premi Invio per conservarlo.', 'Grabado. Pulse Retorno para conservarlo.', 'Optaget. Tryk på Retur for at beholde det.'),
    'Camera Image Window Title': ('Capture Image', 'Capture d’image', 'Bild aufnehmen', 'Cattura immagine', 'Capturar imagen', 'Optag billede'),
    'Camera Movie Window Title': ('Record Movie', 'Enregistrement de séquence', 'Film aufnehmen', 'Registra filmato', 'Grabar película', 'Optag film'),
    'Camera Capture Button': ('Capture', 'Capturer', 'Aufnehmen', 'Cattura', 'Capturar', 'Optag'),
    'Camera Image Ready Status': ('Press Return to take the picture.', 'Appuyez sur Retour pour prendre la photo.', 'Zum Aufnehmen des Bildes die Eingabetaste drücken.', 'Premi Invio per scattare la foto.', 'Pulse Retorno para tomar la foto.', 'Tryk på Retur for at tage billedet.'),
    'Camera Movie Ready Status': ('Press Record (or the space bar) to start.', 'Appuyez sur Enregistrer (ou sur la barre d’espace) pour commencer.', 'Zum Starten „Aufnehmen“ (oder die Leertaste) drücken.', 'Premi Registra (o la barra spaziatrice) per iniziare.', 'Pulse Grabar (o la barra espaciadora) para empezar.', 'Tryk på Optag (eller mellemrumstasten) for at begynde.'),
    'Camera Recording Status': ('Recording… press Return when done.', 'Enregistrement… appuyez sur Retour pour terminer.', 'Aufnahme… zum Beenden die Eingabetaste drücken.', 'Registrazione… premi Invio per terminare.', 'Grabando… pulse Retorno para terminar.', 'Optager… tryk på Retur for at afslutte.'),
    'Microphone Unavailable Title': ('ProVoc cannot use the microphone', 'ProVoc ne peut pas utiliser le microphone', 'ProVoc kann das Mikrofon nicht verwenden', 'ProVoc non può usare il microfono', 'ProVoc no puede usar el micrófono', 'ProVoc kan ikke bruge mikrofonen'),
    'Camera Unavailable Title': ('ProVoc cannot use the camera', 'ProVoc ne peut pas utiliser la caméra', 'ProVoc kann die Kamera nicht verwenden', 'ProVoc non può usare la fotocamera', 'ProVoc no puede usar la cámara', 'ProVoc kan ikke bruge kameraet'),
    'Microphone Access Denied Message': ('Allow ProVoc to use the microphone in System Settings > Privacy & Security > Microphone.', 'Autorisez ProVoc à utiliser le microphone dans Réglages Système > Confidentialité et sécurité > Microphone.', 'Erlauben Sie ProVoc die Verwendung des Mikrofons in Systemeinstellungen > Datenschutz & Sicherheit > Mikrofon.', 'Consenti a ProVoc di usare il microfono in Impostazioni di Sistema > Privacy e sicurezza > Microfono.', 'Permita que ProVoc use el micrófono en Ajustes del Sistema > Privacidad y seguridad > Micrófono.', 'Giv ProVoc lov til at bruge mikrofonen i Systemindstillinger > Anonymitet & sikkerhed > Mikrofon.'),
    'Camera Access Denied Message': ('Allow ProVoc to use the camera in System Settings > Privacy & Security > Camera.', 'Autorisez ProVoc à utiliser la caméra dans Réglages Système > Confidentialité et sécurité > Caméra.', 'Erlauben Sie ProVoc die Verwendung der Kamera in Systemeinstellungen > Datenschutz & Sicherheit > Kamera.', 'Consenti a ProVoc di usare la fotocamera in Impostazioni di Sistema > Privacy e sicurezza > Fotocamera.', 'Permita que ProVoc use la cámara en Ajustes del Sistema > Privacidad y seguridad > Cámara.', 'Giv ProVoc lov til at bruge kameraet i Systemindstillinger > Anonymitet & sikkerhed > Kamera.'),
    'No Microphone Message': ('No microphone was found.', 'Aucun microphone n’a été trouvé.', 'Es wurde kein Mikrofon gefunden.', 'Nessun microfono trovato.', 'No se ha encontrado ningún micrófono.', 'Der blev ikke fundet nogen mikrofon.'),
    'No Camera Message': ('No camera was found.', 'Aucune caméra n’a été trouvée.', 'Es wurde keine Kamera gefunden.', 'Nessuna fotocamera trovata.', 'No se ha encontrado ninguna cámara.', 'Der blev ikke fundet noget kamera.'),
    'Open System Settings Button': ('Open System Settings', 'Ouvrir Réglages Système', 'Systemeinstellungen öffnen', 'Apri Impostazioni di Sistema', 'Abrir Ajustes del Sistema', 'Åbn Systemindstillinger'),
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
