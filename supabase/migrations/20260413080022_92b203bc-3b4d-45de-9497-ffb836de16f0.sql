
-- Create role enum
CREATE TYPE public.app_role AS ENUM ('user', 'supervisor', 'hrdd_admin', 'signatory');

-- Create nomination status enum
CREATE TYPE public.nomination_status AS ENUM ('draft', 'pending_supervisor', 'pending_hrdd', 'approved', 'disapproved');

-- Create form status enum
CREATE TYPE public.form_status AS ENUM ('draft', 'submitted', 'under_review', 'approved', 'returned');

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Profiles table
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  position_title TEXT,
  office_division TEXT,
  salary_grade TEXT,
  date_hired DATE,
  employment_status TEXT,
  years_of_service TEXT,
  contact_number TEXT,
  gender TEXT,
  bio TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- User roles table
CREATE TABLE public.user_roles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE (user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all roles" ON public.user_roles FOR SELECT USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "Admins can manage roles" ON public.user_roles FOR INSERT WITH CHECK (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "Admins can delete roles" ON public.user_roles FOR DELETE USING (public.has_role(auth.uid(), 'hrdd_admin'));

-- Trainings table
CREATE TABLE public.trainings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  date_start DATE,
  date_end DATE,
  time_start TEXT,
  time_end TEXT,
  venue TEXT,
  mode TEXT,
  provider TEXT,
  competency_type TEXT,
  status TEXT DEFAULT 'active',
  max_participants INT,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.trainings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone authenticated can view trainings" ON public.trainings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage trainings" ON public.trainings FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "Admins can update trainings" ON public.trainings FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE TRIGGER update_trainings_updated_at BEFORE UPDATE ON public.trainings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Nominations table
CREATE TABLE public.nominations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  training_id UUID REFERENCES public.trainings(id),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  training_title TEXT,
  date_of_training TEXT,
  date_filed DATE DEFAULT CURRENT_DATE,
  competency_type TEXT,
  venue TEXT,
  -- Participant info
  participant_name TEXT,
  participant_id_number TEXT,
  participant_email TEXT,
  participant_position TEXT,
  participant_office TEXT,
  participant_supervisor TEXT,
  participant_date_hired DATE,
  participant_employment_status TEXT,
  participant_salary_grade TEXT,
  participant_years_of_service TEXT,
  participant_contact TEXT,
  participant_gender TEXT,
  participant_oic TEXT,
  -- Alternate participant
  alt_name TEXT,
  alt_id_number TEXT,
  alt_email TEXT,
  alt_position TEXT,
  alt_date_hired DATE,
  alt_employment_status TEXT,
  alt_salary_grade TEXT,
  alt_years_of_service TEXT,
  alt_contact TEXT,
  alt_gender TEXT,
  -- Justification
  justification TEXT,
  -- GEDSI responses (JSON array of 8 yes/no)
  gedsi_responses JSONB DEFAULT '[]'::jsonb,
  -- Social inclusion
  is_solo_parent BOOLEAN,
  is_indigenous BOOLEAN,
  indigenous_group TEXT,
  -- Status and workflow
  status nomination_status DEFAULT 'draft',
  supervisor_remarks TEXT,
  hrdd_remarks TEXT,
  signatory_remarks TEXT,
  -- Signatures
  user_signature_url TEXT,
  supervisor_signature_url TEXT,
  signatory_signature_url TEXT,
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.nominations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own nominations" ON public.nominations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own nominations" ON public.nominations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own draft nominations" ON public.nominations FOR UPDATE USING (auth.uid() = user_id AND status = 'draft');
CREATE POLICY "Supervisors can view assigned nominations" ON public.nominations FOR SELECT USING (public.has_role(auth.uid(), 'supervisor'));
CREATE POLICY "Supervisors can update nominations" ON public.nominations FOR UPDATE USING (public.has_role(auth.uid(), 'supervisor') AND status = 'pending_supervisor');
CREATE POLICY "HRDD admins can view all nominations" ON public.nominations FOR SELECT USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "HRDD admins can update nominations" ON public.nominations FOR UPDATE USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "Signatories can view nominations" ON public.nominations FOR SELECT USING (public.has_role(auth.uid(), 'signatory'));
CREATE POLICY "Signatories can update nominations" ON public.nominations FOR UPDATE USING (public.has_role(auth.uid(), 'signatory'));
CREATE TRIGGER update_nominations_updated_at BEFORE UPDATE ON public.nominations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Job Analysis Forms table
CREATE TABLE public.job_analysis_forms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  full_name TEXT,
  position_title TEXT,
  office_division TEXT,
  section_unit TEXT,
  alternate_position TEXT,
  job_purpose TEXT,
  main_duties TEXT,
  secondary_duties JSONB DEFAULT '[]'::jsonb,
  required_competencies JSONB DEFAULT '[]'::jsonb,
  tools_equipment TEXT,
  challenges TEXT,
  additional_comments TEXT,
  status form_status DEFAULT 'draft',
  supervisor_remarks TEXT,
  user_signature_url TEXT,
  date_submitted DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.job_analysis_forms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own JA forms" ON public.job_analysis_forms FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own JA forms" ON public.job_analysis_forms FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own draft JA forms" ON public.job_analysis_forms FOR UPDATE USING (auth.uid() = user_id AND status = 'draft');
CREATE POLICY "Supervisors can view JA forms" ON public.job_analysis_forms FOR SELECT USING (public.has_role(auth.uid(), 'supervisor'));
CREATE POLICY "Supervisors can update JA forms" ON public.job_analysis_forms FOR UPDATE USING (public.has_role(auth.uid(), 'supervisor'));
CREATE POLICY "HRDD admins can view all JA forms" ON public.job_analysis_forms FOR SELECT USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE POLICY "HRDD admins can update JA forms" ON public.job_analysis_forms FOR UPDATE USING (public.has_role(auth.uid(), 'hrdd_admin'));
CREATE TRIGGER update_ja_forms_updated_at BEFORE UPDATE ON public.job_analysis_forms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Notifications table
CREATE TABLE public.notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  related_id UUID,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "System can create notifications" ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, email)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''), NEW.email);
  -- Default role is 'user'
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create storage bucket for signatures and documents
INSERT INTO storage.buckets (id, name, public) VALUES ('documents', 'documents', false);
CREATE POLICY "Users can upload own documents" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can view own documents" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'documents' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Admins can view all documents" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'documents' AND public.has_role(auth.uid(), 'hrdd_admin'));
