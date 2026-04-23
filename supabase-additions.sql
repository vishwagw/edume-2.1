-- ============================================================
--  EDUME LEARNING — Schema Additions (Production)
--  Run in Supabase SQL Editor AFTER the base supabase-schema.sql
-- ============================================================

-- Lesson progress (per user per lesson)
CREATE TABLE IF NOT EXISTS lesson_progress (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  course_id   UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  lesson_id   UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  completed   BOOLEAN DEFAULT FALSE,
  watch_time_sec INTEGER DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own progress" ON lesson_progress FOR ALL USING (user_id = auth.uid());
CREATE TRIGGER lp_updated_at BEFORE UPDATE ON lesson_progress FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Lesson notes
CREATE TABLE IF NOT EXISTS lesson_notes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  lesson_id   UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  content     TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);
ALTER TABLE lesson_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own notes" ON lesson_notes FOR ALL USING (user_id = auth.uid());

-- Lesson resources (PDFs, docs)
CREATE TABLE IF NOT EXISTS lesson_resources (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lesson_id  UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  url        TEXT NOT NULL,
  file_size  BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE lesson_resources ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enrolled students can view resources"
  ON lesson_resources FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM course_lessons cl
      JOIN enrollments e ON e.course_id = cl.course_id
      WHERE cl.id = lesson_resources.lesson_id AND e.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM course_lessons cl
      JOIN courses c ON c.id = cl.course_id
      WHERE cl.id = lesson_resources.lesson_id AND c.instructor_id = auth.uid()
    )
  );
CREATE POLICY "Instructors can insert resources"
  ON lesson_resources FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM course_lessons cl
      JOIN courses c ON c.id = cl.course_id
      WHERE cl.id = lesson_resources.lesson_id AND c.instructor_id = auth.uid()
    )
  );
CREATE POLICY "Instructors can delete resources"
  ON lesson_resources FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM course_lessons cl
      JOIN courses c ON c.id = cl.course_id
      WHERE cl.id = lesson_resources.lesson_id AND c.instructor_id = auth.uid()
    )
  );

-- Add description column to course_lessons if not exists
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS resource_urls TEXT[];

-- Enable Realtime on lesson_progress for live progress sync
ALTER PUBLICATION supabase_realtime ADD TABLE lesson_progress;
