import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";

import { Toaster as Sonner } from "@/components/ui/sonner";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { ZiitoProvider } from "@/store/ZiitoStore";

import { AppLayout } from "@/components/app/AppLayout";
import Today from "./pages/app/Today";
import Schedule from "./pages/app/Schedule";
import Mountain from "./pages/app/Mountain";
import More from "./pages/app/More";
import Tasks from "./pages/app/Tasks";
import Exams from "./pages/app/Exams";
import Subjects from "./pages/app/Subjects";
import CalendarPage from "./pages/app/CalendarPage";
import Stats from "./pages/app/Stats";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <ZiitoProvider>
        <BrowserRouter>
          <Routes>
            <Route element={<AppLayout />}>
              <Route path="/" element={<Today />} />
              <Route path="/horario" element={<Schedule />} />
              <Route path="/montana" element={<Mountain />} />
              <Route path="/mas" element={<More />} />
              <Route path="/mas/tareas" element={<Tasks />} />
              <Route path="/mas/evaluaciones" element={<Exams />} />
              <Route path="/mas/materias" element={<Subjects />} />
              <Route path="/mas/calendario" element={<CalendarPage />} />
              <Route path="/mas/estadisticas" element={<Stats />} />
            </Route>
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </ZiitoProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
