import { Outlet } from "react-router-dom";

import { TabBar } from "@/components/app/TabBar";
import { ActiveFocusBar } from "@/components/app/ActiveFocusBar";
import { FocusMode } from "@/components/app/FocusMode";
import { GuidedTour } from "@/components/app/GuidedTour";

export function AppLayout() {
  return (
    <div className="flex min-h-[100dvh] flex-col bg-background text-foreground">
      <main className="mx-auto w-full max-w-lg flex-1 px-4 pb-4 pt-[max(env(safe-area-inset-top),12px)]">
        <Outlet />
      </main>
      <div className="sticky bottom-[calc(env(safe-area-inset-bottom)+56px)] z-20">
        <ActiveFocusBar />
      </div>
      <TabBar />
      <FocusMode />
      <GuidedTour />
    </div>
  );
}
