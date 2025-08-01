import QtQuick
import QtQuick.Controls
import Qt.labs.platform
import QtQuick.Layouts
import Quickshell

QtObject {
    id: dictionaryService

    signal resultsReady(var results)

    function searchDictionary(query) {
        var process = Qt.createQmlObject('import Qt.labs.platform; Process {}', dictionaryService);
        process.command = ["dict", "-d", "wn", query];
        process.onReadyReadStandardOutput.connect(function() {
            var output = process.readAllStandardOutput();
            var entries = parseDictOutput(output);
            resultsReady(entries);
        });
        process.start();
    }

    /**
 * Parses the raw output from the `dict -h localhost -f <word> wordnet` command
 * when only the WordNet dictionary is used, extracting the definitions.
 *
 * @param {string} dictOutput The full string output from the dict command for a single wordnet definition.
 * @param {string} word The word that was looked up (used to find the start of definitions).
 * @returns {string[]} An array of strings, where each string is a WordNet definition.
 *                     Returns an empty array if no definitions are found or if the format is unexpected.
 */
function parseDictOutput(dictOutput, word) {
  const definitions = [];
  const lines = dictOutput.split('\n');
  let startParsing = false;

  const trimmedWord = word.trim().toLowerCase(); // Normalize the word for matching

  for (const line of lines) {
    const trimmedLine = line.trim();

    // Look for the line where the word itself is presented (e.g., "yes")
    // This marks the beginning of the definition block
    if (trimmedLine.toLowerCase() === trimmedWord) {
      startParsing = true;
      continue; // Skip this line itself
    }

    // Once we've found the word, start processing lines
    if (startParsing) {
      // Check if the line looks like a definition (e.g., starts with "n 1: ")
      // This regex looks for optional part-of-speech (like 'n' or 'v'), a number, and a colon,
      // followed by the actual definition text.
      const definitionMatch = trimmedLine.match(/^([a-z]\s\d+:\s)(.*)/);

      if (definitionMatch && definitionMatch[2]) {
        // The second capturing group `definitionMatch[2]` contains the actual definition
        definitions.push(definitionMatch[2].trim());
      } else if (trimmedLine.length === 0) {
        // If we encounter an empty line after starting to parse, it might signify the end
        // of definitions if there were no more definition-like lines immediately after.
        // This break is a bit aggressive and might need adjustment if definitions can have internal empty lines,
        // but for typical WordNet output, it works.
        // For your specific sample, definitions don't seem to have empty lines in between.
        break;
      }
      // If a line doesn't match the definition pattern and isn't empty,
      // it means we've probably moved past the definitions.
      // This implicitly handles other lines like '[ant: {no}]' or similar metadata that might appear.
    }
  }

  return definitions;
}

    function selectEntry(entry) {
        console.log("Selected:", entry.word);
        console.log("Definition:", entry.definition);
        // Additional processing can be added here
    }
}

