
DROP POLICY "System can create notifications" ON public.notifications;
CREATE POLICY "Users can create notifications" ON public.notifications FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR public.has_role(auth.uid(), 'hrdd_admin') OR public.has_role(auth.uid(), 'supervisor'));
