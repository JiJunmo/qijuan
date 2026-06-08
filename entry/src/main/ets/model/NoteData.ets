import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

export class NoteItem {
  id: string;
  bookId: string;
  title: string;
  fileName: string;
  updateTime: string;

  constructor(id: string, bookId: string, title: string, fileName: string, updateTime: string) {
    this.id = id;
    this.bookId = bookId;
    this.title = title;
    this.fileName = fileName;
    this.updateTime = updateTime;
  }
}

export function parseMarkdownToHtml(md: string): string {
  let html = md || '';
  // Basic HTML escape to prevent tags from breaking rendering
  html = html.replace(/</g, '&lt;').replace(/>/g, '&gt;');
  
  // Headings
  html = html.replace(/^######\s+(.*)$/gm, '<h6>$1</h6>');
  html = html.replace(/^#####\s+(.*)$/gm, '<h5>$1</h5>');
  html = html.replace(/^####\s+(.*)$/gm, '<h4>$1</h4>');
  html = html.replace(/^###\s+(.*)$/gm, '<h3>$1</h3>');
  html = html.replace(/^##\s+(.*)$/gm, '<h2>$1</h2>');
  html = html.replace(/^#\s+(.*)$/gm, '<h1>$1</h1>');
  
  // Bold
  html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
  
  // Blockquote (since '>' was escaped to '&gt;')
  html = html.replace(/^&gt;\s+(.*)$/gm, '<blockquote style="border-left: 4px solid #4A6B82; padding-left: 12px; color: #555; margin: 12px 0; background: #F5F7F8; padding: 8px;">$1</blockquote>');
  
  // Simple Tables
  let lines = html.split('\n');
  let inTable = false;
  let isHeader = false;
  for(let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    if (line.startsWith('|') && line.endsWith('|')) {
      // Table separator
      if (line.match(/^\|(?:\s*[:-]+[-]*\s*\|)+$/)) {
        lines[i] = '';
        isHeader = false;
        continue;
      }
      let cells = line.substring(1, line.length - 1).split('|');
      let cellTag = isHeader ? 'th' : 'td';
      let cellStyle = isHeader 
        ? 'border: 1px solid #ddd; padding: 8px; background-color: #f2f2f2; font-weight: bold; text-align: left;' 
        : 'border: 1px solid #ddd; padding: 8px; text-align: left;';
      let tr = '<tr>' + cells.map(c => `<${cellTag} style="${cellStyle}">${c.trim()}</${cellTag}>`).join('') + '</tr>';
      
      if (!inTable) {
        lines[i] = '<table style="border-collapse: collapse; width: 100%; font-size: 14px; margin: 12px 0;">' + tr;
        inTable = true;
        isHeader = true; // Next rows should be td
      } else {
        lines[i] = tr;
      }
    } else {
      if (inTable) {
        lines[i-1] += '</table>';
        inTable = false;
      }
      if (lines[i] && !lines[i].startsWith('<h') && !lines[i].startsWith('<block') && !lines[i].startsWith('<table') && !lines[i].startsWith('<tr')) {
        lines[i] = '<p style="font-size:14px; line-height: 1.6; color: #333; margin: 8px 0;">' + lines[i] + '</p>';
      }
    }
  }
  if (inTable) lines[lines.length-1] += '</table>';
  
  // Wrap in body with safe padding
  return `<html><body style="font-family: sans-serif; padding: 8px;">${lines.join('\n')}</body></html>`;
}

export function saveNoteToFile(context: common.UIAbilityContext, fileName: string, content: string) {
  let path = context.filesDir + '/' + fileName;
  let file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  fs.writeSync(file.fd, content);
  fs.closeSync(file);
}

export function readNoteFromFile(context: common.UIAbilityContext, fileName: string): string {
  let path = context.filesDir + '/' + fileName;
  try {
    return fs.readTextSync(path);
  } catch (e) {
    console.error('readNoteFromFile error', JSON.stringify(e));
    return '';
  }
}
