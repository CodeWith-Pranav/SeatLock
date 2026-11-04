import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'SeatLock — Your next great experience',description:'Discover campus events. Reserve your place with confidence.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
