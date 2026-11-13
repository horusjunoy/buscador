import hashlib
import hmac
import secrets
from threading import BoundedSemaphore
from datetime import timedelta
from .models import AuthSession, now

_password_slots=BoundedSemaphore(2)
def derive(password,salt,work_factor):
    with _password_slots:
        return hashlib.scrypt(password.encode(),salt=bytes.fromhex(salt),n=work_factor,r=8,p=1,dklen=32,maxmem=256*1024*1024)

def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()

def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    derived = derive(password,salt,2**17)
    return f'scrypt17${salt}${derived.hex()}'

def verify_password(password: str, encoded: str) -> bool:
    algorithm, salt, expected = encoded.split('$')
    actual = derive(password,salt,2**17 if algorithm=='scrypt17' else 2**14)
    return hmac.compare_digest(actual.hex(), expected)

def issue_session(db, actor_id):
    token = secrets.token_urlsafe(48)
    expiry = now()+timedelta(hours=12)
    db.add(AuthSession(token_hash=digest(token), account_id=actor_id, expires_at=expiry))
    return {'access_token': token, 'token_type': 'bearer', 'expires_at': expiry, 'account_id': actor_id}
