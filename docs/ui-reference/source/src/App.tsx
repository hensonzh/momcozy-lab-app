import { Navigate, Route, Routes } from 'react-router-dom'
import UserApp, { AuthPage } from './pages/UserApp'
import Workbench, { WorkbenchAuthPage } from './pages/Workbench'

export default function App() {
  return <Routes>
    <Route path="/auth" element={<AuthPage />} />
    <Route path="/ibclc/auth" element={<WorkbenchAuthPage />} />
    <Route path="/app/*" element={<UserApp />} />
    <Route path="/ibclc/*" element={<Workbench />} />
    <Route path="*" element={<Navigate to="/app/home" replace />} />
  </Routes>
}
