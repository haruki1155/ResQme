// Isolated-profile entry ONLY. Production package.json continues to use src/index.
import {resolveTier1Qr as original} from '../src/qr/resolve_tier1_qr';
import {observeQrHttp} from './helpers/qr_http_observer';

if(process.env.RESQME_QR_HTTP_OBSERVER!=='1'||process.env.GCLOUD_PROJECT!=='demo-resqme') {
  throw new Error('QR HTTP observer requires an explicitly enabled isolated demo profile.');
}

export * from '../src/index';
export const resolveTier1Qr=observeQrHttp(original,category=>{
  console.info(JSON.stringify({diagnostic:'qr_http_metadata',...category}));
});
