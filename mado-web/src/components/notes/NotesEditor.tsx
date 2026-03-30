'use client'

import { useEffect } from 'react'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Placeholder from '@tiptap/extension-placeholder'
import { useNotesStore } from '@/stores/notesStore'
import {
  Heading1,
  Heading2,
  Heading3,
  Bold,
  Italic,
  Code,
  List,
  ListOrdered,
  Quote,
  SquareCode,
} from 'lucide-react'

function ToolbarButton({
  onClick,
  active,
  title,
  children,
}: {
  onClick: () => void
  active?: boolean
  title: string
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      title={title}
      onClick={onClick}
      className={`flex h-7 w-7 items-center justify-center rounded transition ${
        active
          ? 'bg-accent-light text-accent'
          : 'text-text-secondary hover:bg-hover-bg hover:text-text-primary'
      }`}
    >
      {children}
    </button>
  )
}

export function NotesEditor() {
  const selectedNoteId = useNotesStore((s) => s.selectedNoteId)
  const notes = useNotesStore((s) => s.notes)
  const updateNoteContent = useNotesStore((s) => s.updateNoteContent)

  const selectedNote = notes.find((n) => n.id === selectedNoteId)

  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({ placeholder: 'Start writing...' }),
    ],
    content: selectedNote?.content ?? '',
    editorProps: {
      attributes: {
        class:
          'prose prose-sm max-w-none h-full min-h-[calc(100vh-8rem)] outline-none text-text-primary [&_h1]:text-2xl [&_h1]:font-bold [&_h1]:mb-3 [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:mb-2 [&_h3]:text-lg [&_h3]:font-medium [&_h3]:mb-2 [&_p]:mb-2 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:mb-2 [&_ol]:list-decimal [&_ol]:pl-5 [&_ol]:mb-2 [&_blockquote]:border-l-4 [&_blockquote]:border-accent [&_blockquote]:pl-4 [&_blockquote]:text-text-secondary [&_code]:bg-surface-secondary [&_code]:rounded [&_code]:px-1 [&_code]:py-0.5 [&_code]:text-xs [&_pre]:bg-surface-secondary [&_pre]:rounded-lg [&_pre]:p-4 [&_pre]:text-xs [&_pre_code]:bg-transparent [&_pre_code]:p-0',
      },
    },
    onUpdate: ({ editor }) => {
      if (selectedNoteId) {
        updateNoteContent(selectedNoteId, editor.getHTML())
      }
    },
  })

  // Sync editor content when selected note changes
  useEffect(() => {
    if (!editor) return
    const content = selectedNote?.content ?? ''
    if (editor.getHTML() !== content) {
      editor.commands.setContent(content, { emitUpdate: false })
    }
  }, [selectedNoteId, editor]) // eslint-disable-line react-hooks/exhaustive-deps

  if (!selectedNote) {
    return (
      <div className="flex flex-1 items-center justify-center">
        <div className="text-center">
          <p className="text-sm font-medium text-text-secondary">No note selected</p>
          <p className="mt-1 text-xs text-text-tertiary">Select a note or create a new one</p>
        </div>
      </div>
    )
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      {/* Toolbar */}
      <div className="flex items-center gap-0.5 border-b border-divider bg-surface px-4 py-1.5">
        <ToolbarButton
          title="Heading 1"
          onClick={() => editor?.chain().focus().toggleHeading({ level: 1 }).run()}
          active={editor?.isActive('heading', { level: 1 })}
        >
          <Heading1 className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Heading 2"
          onClick={() => editor?.chain().focus().toggleHeading({ level: 2 }).run()}
          active={editor?.isActive('heading', { level: 2 })}
        >
          <Heading2 className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Heading 3"
          onClick={() => editor?.chain().focus().toggleHeading({ level: 3 }).run()}
          active={editor?.isActive('heading', { level: 3 })}
        >
          <Heading3 className="h-4 w-4" />
        </ToolbarButton>

        <div className="mx-1 h-4 w-px bg-divider" />

        <ToolbarButton
          title="Bold"
          onClick={() => editor?.chain().focus().toggleBold().run()}
          active={editor?.isActive('bold')}
        >
          <Bold className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Italic"
          onClick={() => editor?.chain().focus().toggleItalic().run()}
          active={editor?.isActive('italic')}
        >
          <Italic className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Inline Code"
          onClick={() => editor?.chain().focus().toggleCode().run()}
          active={editor?.isActive('code')}
        >
          <Code className="h-4 w-4" />
        </ToolbarButton>

        <div className="mx-1 h-4 w-px bg-divider" />

        <ToolbarButton
          title="Bullet List"
          onClick={() => editor?.chain().focus().toggleBulletList().run()}
          active={editor?.isActive('bulletList')}
        >
          <List className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Ordered List"
          onClick={() => editor?.chain().focus().toggleOrderedList().run()}
          active={editor?.isActive('orderedList')}
        >
          <ListOrdered className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Blockquote"
          onClick={() => editor?.chain().focus().toggleBlockquote().run()}
          active={editor?.isActive('blockquote')}
        >
          <Quote className="h-4 w-4" />
        </ToolbarButton>
        <ToolbarButton
          title="Code Block"
          onClick={() => editor?.chain().focus().toggleCodeBlock().run()}
          active={editor?.isActive('codeBlock')}
        >
          <SquareCode className="h-4 w-4" />
        </ToolbarButton>
      </div>

      {/* Editor area */}
      <div className="flex-1 overflow-y-auto px-8 py-6">
        <div className="mx-auto max-w-2xl">
          <h1 className="mb-4 text-2xl font-bold text-text-primary">{selectedNote.displayName}</h1>
          <EditorContent editor={editor} />
        </div>
      </div>
    </div>
  )
}
